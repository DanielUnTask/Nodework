--- Signal Types
export type Connection<T... = ()> = {
	Connected: boolean,
	Disconnect: (self: Connection<T...>) -> (),
	Destroy: (self: Connection<T...>) -> (),
}

export type Signal<T... = ()> = {
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	Once: (self: Signal<T...>, (T...) -> ()) -> Connection<T...>,
	Connect: (self: Signal<T...>, (T...) -> ()) -> Connection<T...>,
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

export type SignalConstructor = {
	new: <T...>() -> Signal<T...>,
	wrap: <T...>(scriptSignal: RBXScriptSignal) -> Signal<T...>,
}

--- Promise Types
type PromiseStatus = "Started" | "Resolved" | "Rejected" | "Cancelled"

export type Promise<T... = ()> = {
	now: (self: Promise<T...>, rejectionValue: any?) -> Promise<T...>,
	cancel: (self: Promise<T...>) -> (),
	timeout: (self: Promise<T...>, seconds: number, rejectionValue: any?) -> Promise<T...>,
	getStatus: (self: Promise<T...>) -> PromiseStatus,

	tap: (self: Promise<T...>, tapHandler: (T...) -> ...any) -> Promise<T...>,
	catch: (self: Promise<T...>, failureHandler: (...any) -> ...any) -> Promise<T...>,
	andThen: (
		self: Promise<T...>,
		successHandler: (T...) -> ...any,
		failureHandler: ((...any) -> ...any)?
	) -> Promise<T...>,

	finally: (self: Promise<T...>, finallyHandler: (status: PromiseStatus) -> ...any) -> Promise<T...>,
	finallyCall: (self: Promise<T...>, finallyHandler: (...any) -> ...any, ...any?) -> Promise<T...>,
	finallyReturn: (self: Promise<T...>, ...any?) -> Promise<T...>,

	andThenCall: <P...>(self: Promise<T...>, callback: (P...) -> ...any, P...) -> Promise<T...>,
	andThenReturn: (self: Promise<T...>, T...) -> Promise<T...>,

	await: (self: Promise<T...>) -> (boolean, T...),
	expect: (self: Promise<T...>) -> T...,
	awaitStatus: (self: Promise<T...>) -> (PromiseStatus, T...),
}

export type PromiseConstructor = {
	Error: any,

	new: (
		executor: (
			resolve: (...any) -> ...any,
			reject: (...any) -> (),
			onCancel: (abortHandler: () -> ()?) -> boolean
		) -> ()
	) -> Promise,

	defer: (
		executor: (
			resolve: (...any) -> ...any,
			reject: (...any) -> (),
			onCancel: (abortHandler: () -> ()?) -> boolean
		) -> ()
	) -> Promise,

	each: <T, U>(
		list: { T | Promise<T> },
		predicate: (value: T, index: number) -> U | Promise<U>
	) -> Promise<{ U }>,

	fold: <T, U>(
		list: { T | Promise<T> },
		reducer: (accumulator: U, value: T, index: number) -> U | Promise<U>,
		initialValue: U
	) -> (),

	retryWithDelay: <T, P>(
		callback: (...P) -> Promise<T>,
		times: number,
		seconds: number,
		...P?
	) -> Promise<T>,

	fromEvent: <P, T...>(event: RBXScriptSignal | Signal<T...>, predicate: ((...P) -> boolean)?) -> Promise<P>,

	delay: (seconds: number) -> Promise<number>,
	reject: (...any) -> Promise<...any>,
	resolve: <T...>(T...) -> Promise<T...>,

	try: <T...>(callback: (T...) -> ...any, T...) -> Promise,
	retry: <T, P>(callback: (...P) -> Promise<T>, times: number, ...P?) -> Promise<T>,

	any: <T>(promises: { Promise<T> }) -> Promise<T>,
	all: <T>(promises: { Promise<T> }) -> Promise<{ T }>,
	race: <T>(promises: { Promise<T> }) -> Promise<{ T }>,
	some: <T>(promises: { Promise<T> }, count: number) -> Promise<{ T }>,
	allSettled: <T>(promises: { Promise<T> }) -> Promise<{ PromiseStatus }>,

	is: (object: any) -> boolean,
	promisify: (callback: (...any) -> ...any) -> (...any) -> Promise,
	onUnhandledRejection: (callback: (promise: Promise, ...any) -> ()) -> (),
}

--- Import
local Packages = (script.Parent :: Instance).Parent
local Signal = (require(Packages.Signal) :: any) :: SignalConstructor
local Promise = (require(Packages.Promise) :: any) :: PromiseConstructor

return {
	Signal = Signal,
	Promise = Promise,
}
