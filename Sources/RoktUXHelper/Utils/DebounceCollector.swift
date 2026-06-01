import Combine

@available(iOS 13.0, *)
struct DebounceCollector<Upstream: Publisher, S: Scheduler>: Publisher {

    typealias Output = [Upstream.Output]
    typealias Failure = Upstream.Failure

    let upstream: Upstream
    let dueTime: S.SchedulerTimeType.Stride
    let scheduler: S
    let options: S.SchedulerOptions?

    func receive<Sub>(subscriber: Sub) where Sub: Subscriber, Upstream.Failure == Sub.Failure, [Upstream.Output] == Sub.Input {
        let debounceSubscriber = DebounceCollectorSubscriber(
            downstream: subscriber,
            dueTime: dueTime,
            scheduler: scheduler,
            options: options
        )
        upstream.subscribe(debounceSubscriber)
    }
}

@available(iOS 13.0, *)
extension DebounceCollector {
    class DebounceCollectorSubscriber<Downstream: Subscriber, DownstreamScheduler: Scheduler>: Subscriber
    where
    Downstream.Input == [Upstream.Output],
    Downstream.Failure == Failure {
        typealias Input = Upstream.Output
        typealias Failure = Downstream.Failure

        private let downstream: Downstream
        private let dueTime: DownstreamScheduler.SchedulerTimeType.Stride
        private let scheduler: DownstreamScheduler
        private let options: DownstreamScheduler.SchedulerOptions?
        private var lastCancellable: Cancellable?
        private var collectedValues: [Input] = []

        init(
            downstream: Downstream,
            dueTime: DownstreamScheduler.SchedulerTimeType.Stride,
            scheduler: DownstreamScheduler,
            options: DownstreamScheduler.SchedulerOptions? = nil
        ) {
            self.downstream = downstream
            self.dueTime = dueTime
            self.scheduler = scheduler
            self.options = options
        }

        func receive(subscription: Combine.Subscription) {
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            collectedValues.append(input)

            lastCancellable?.cancel()
            lastCancellable = scheduler.schedule(
                after: scheduler.now.advanced(by: dueTime),
                interval: .zero,
                tolerance: .zero
            ) { [weak self] in
                guard let collectedValues = self?.collectedValues else { return }
                _ = self?.downstream.receive(collectedValues)
                self?.collectedValues = []
                self?.lastCancellable?.cancel()
            }

            return .none
        }

        func receive(completion: Subscribers.Completion<Downstream.Failure>) {
            downstream.receive(completion: completion)
        }
    }
}

@available(iOS 13.0, *)
extension Publisher {
    func debounceCollect<S: Scheduler>(
        for dueTime: S.SchedulerTimeType.Stride,
        scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> DebounceCollector<Self, S> {
        DebounceCollector(
            upstream: self,
            dueTime: dueTime,
            scheduler: scheduler,
            options: options
        )
    }
}
