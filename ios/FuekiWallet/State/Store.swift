//
//  Store.swift
//  FuekiWallet
//
//  Redux-style store for state management
//

import Foundation
import Combine

// MARK: - Action Protocol
protocol Action {}

// MARK: - Reducer Type
typealias Reducer<State> = (inout State, Action) -> Void

// MARK: - Middleware Type
typealias Middleware<State> = (State, Action) -> AnyPublisher<Action, Never>?

// MARK: - Store
final class Store<State>: ObservableObject {

    // MARK: - Properties
    @Published private(set) var state: State

    private let reducer: Reducer<State>
    private var middlewares: [Middleware<State>]
    private var cancellables = Set<AnyCancellable>()

    private let stateSubject = PassthroughSubject<State, Never>()
    private let actionSubject = PassthroughSubject<Action, Never>()

    // Thread-safe access queue
    private let queue = DispatchQueue(label: "io.fueki.wallet.store", qos: .userInitiated)

    // MARK: - State History (for time-travel debugging)
    private var stateHistory: [State] = []
    private var actionHistory: [Action] = []
    private let maxHistorySize: Int = 50
    private var isRecordingHistory: Bool = true

    // MARK: - Initialization
    init(
        initialState: State,
        reducer: @escaping Reducer<State>,
        middlewares: [Middleware<State>] = []
    ) {
        self.state = initialState
        self.reducer = reducer
        self.middlewares = middlewares

        // Record initial state
        stateHistory.append(initialState)
    }

    // MARK: - Dispatch
    func dispatch(_ action: Action) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Record action
            if self.isRecordingHistory {
                self.recordAction(action)
            }

            // Execute middlewares
            self.executeMiddlewares(action)

            // Apply reducer
            self.applyReducer(action)

            // Publish action
            self.actionSubject.send(action)
        }
    }

    // MARK: - Batch Dispatch
    func batchDispatch(_ actions: [Action]) {
        queue.async { [weak self] in
            guard let self = self else { return }

            actions.forEach { action in
                if self.isRecordingHistory {
                    self.recordAction(action)
                }
                self.executeMiddlewares(action)
                self.applyReducer(action)
                self.actionSubject.send(action)
            }
        }
    }

    // MARK: - Private Methods
    private func applyReducer(_ action: Action) {
        var newState = state
        reducer(&newState, action)

        // Record state change
        if isRecordingHistory {
            recordState(newState)
        }

        // Update published state on main thread
        DispatchQueue.main.async {
            self.state = newState
            self.stateSubject.send(newState)
        }
    }

    private func executeMiddlewares(_ action: Action) {
        middlewares.forEach { middleware in
            middleware(state, action)?
                .receive(on: DispatchQueue.main)
                .sink(receiveValue: { [weak self] newAction in
                    self?.dispatch(newAction)
                })
                .store(in: &cancellables)
        }
    }

    private func recordState(_ state: State) {
        stateHistory.append(state)
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst()
        }
    }

    private func recordAction(_ action: Action) {
        actionHistory.append(action)
        if actionHistory.count > maxHistorySize {
            actionHistory.removeFirst()
        }
    }

    // MARK: - Time Travel
    func enableTimeTravel(_ enabled: Bool) {
        queue.async {
            self.isRecordingHistory = enabled
        }
    }

    func rewindToState(at index: Int) {
        queue.async {
            guard index >= 0, index < self.stateHistory.count else { return }
            let previousState = self.stateHistory[index]

            DispatchQueue.main.async {
                self.state = previousState
                self.stateSubject.send(previousState)
            }
        }
    }

    func getStateHistory() -> [State] {
        queue.sync {
            stateHistory
        }
    }

    func getActionHistory() -> [Action] {
        queue.sync {
            actionHistory
        }
    }

    func clearHistory() {
        queue.async {
            self.stateHistory = [self.state]
            self.actionHistory = []
        }
    }

    // MARK: - Observation
    func observe<T>(_ keyPath: KeyPath<State, T>) -> AnyPublisher<T, Never> where T: Equatable {
        $state
            .map(keyPath)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func observeState() -> AnyPublisher<State, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    func observeActions() -> AnyPublisher<Action, Never> {
        actionSubject.eraseToAnyPublisher()
    }

    // MARK: - Middleware Management
    func addMiddleware(_ middleware: @escaping Middleware<State>) {
        queue.async {
            self.middlewares.append(middleware)
        }
    }

    func removeAllMiddlewares() {
        queue.async {
            self.middlewares.removeAll()
        }
    }

    // MARK: - Debug
    func printState() {
        queue.async {
            print("📊 Current State:")
            dump(self.state)
        }
    }

    func printHistory() {
        queue.async {
            print("📜 State History (\(self.stateHistory.count) states):")
            self.stateHistory.enumerated().forEach { index, state in
                print("  [\(index)]")
                dump(state)
            }
            print("📜 Action History (\(self.actionHistory.count) actions):")
            self.actionHistory.enumerated().forEach { index, action in
                print("  [\(index)] \(type(of: action))")
            }
        }
    }
}

// MARK: - AppStore Singleton
final class AppStore {
    static let shared = Store(
        initialState: AppState.initial,
        reducer: appReducer,
        middlewares: [
            loggingMiddleware,
            analyticsMiddleware,
            persistenceMiddleware
        ]
    )

    private init() {}
}

// MARK: - Store Extensions
extension Store where State == AppState {

    // Convenience accessors
    var walletState: WalletState {
        state.wallet
    }

    var transactionState: TransactionState {
        state.transactions
    }

    var settingsState: SettingsState {
        state.settings
    }

    var authState: AuthState {
        state.auth
    }

    var uiState: UIState {
        state.ui
    }

    // Convenience observers
    func observeWallet() -> AnyPublisher<WalletState, Never> {
        observe(\.wallet)
    }

    func observeTransactions() -> AnyPublisher<TransactionState, Never> {
        observe(\.transactions)
    }

    func observeSettings() -> AnyPublisher<SettingsState, Never> {
        observe(\.settings)
    }

    func observeAuth() -> AnyPublisher<AuthState, Never> {
        observe(\.auth)
    }

    func observeUI() -> AnyPublisher<UIState, Never> {
        observe(\.ui)
    }
}
