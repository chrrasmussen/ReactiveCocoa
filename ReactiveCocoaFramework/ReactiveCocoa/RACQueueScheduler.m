//
//  RACQueueScheduler.m
//  ReactiveCocoa
//
//  Created by Josh Abernathy on 11/30/12.
//  Copyright (c) 2012 GitHub, Inc. All rights reserved.
//

#import "RACQueueScheduler.h"
#import "RACDisposable.h"
#import "RACScheduler+Private.h"
#import <libkern/OSAtomic.h>

@interface RACQueueScheduler ()
@property (nonatomic, readonly) dispatch_queue_t queue;
@end

@implementation RACQueueScheduler

#pragma mark Lifecycle

- (void)dealloc {
	dispatch_release(_queue);
}

- (id)initWithName:(NSString *)name targetQueue:(dispatch_queue_t)targetQueue {
	NSParameterAssert(targetQueue != NULL);

	_queue = dispatch_queue_create(name.UTF8String, DISPATCH_QUEUE_SERIAL);
	if (_queue == nil) return nil;

	dispatch_set_target_queue(_queue, targetQueue);
	
	return [super initWithName:name];
}

#pragma mark Current Scheduler

static void currentSchedulerRelease(void *context) {
	CFBridgingRelease(context);
}

- (void)performAsCurrentScheduler:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	dispatch_queue_set_specific(self.queue, RACSchedulerCurrentSchedulerKey, (void *)CFBridgingRetain(self), currentSchedulerRelease);
	block();
	dispatch_queue_set_specific(self.queue, RACSchedulerCurrentSchedulerKey, nil, currentSchedulerRelease);
}

#pragma mark RACScheduler

- (RACDisposable *)schedule:(void (^)(void))block {
	NSParameterAssert(block != NULL);

	__block volatile uint32_t disposed = 0;

	dispatch_async(self.queue, ^{
		if (disposed) return;
		[self performAsCurrentScheduler:block];
	});

	return [RACDisposable disposableWithBlock:^{
		OSAtomicOr32Barrier(1, &disposed);
	}];
}

@end
