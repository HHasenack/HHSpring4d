{***************************************************************************}
{                                                                           }
{           Spring Framework for Delphi                                     }
{                                                                           }
{           Copyright (c) 2009-2017 Spring4D Team                           }
{                                                                           }
{           http://www.spring4d.org                                         }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Licensed under the Apache License, Version 2.0 (the "License");          }
{  you may not use this file except in compliance with the License.         }
{  You may obtain a copy of the License at                                  }
{                                                                           }
{      http://www.apache.org/licenses/LICENSE-2.0                           }
{                                                                           }
{  Unless required by applicable law or agreed to in writing, software      }
{  distributed under the License is distributed on an "AS IS" BASIS,        }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. }
{  See the License for the specific language governing permissions and      }
{  limitations under the License.                                           }
{                                                                           }
{***************************************************************************}

{$I Spring.inc}

unit Spring.Reactive;

interface

uses
  Classes,
  Rtti,
  SyncObjs,
  SysUtils,
  Spring,
  Spring.Collections,
  Spring.Reactive.TimeInterval;

type
  Exception = SysUtils.Exception;

  TTimeSpan = Spring.TTimeSpan;
  TTimeSpanHelper = record helper for TTimeSpan
    class function &&op_Implicit(const value: Double): TTimeSpan; static;
  end;

  TThread = Classes.TThread;
  TThreadHelper = class helper for TThread
  private
    function GetTerminated: Boolean;
  public
    class procedure Sleep(const timeout: TTimeSpan); overload; static;
    property Terminated: Boolean read GetTerminated;
  end;

  {$REGION 'Disposables'}

  IDisposable = interface // TODO: consider moving to Spring.pas
    ['{DD824C60-FFF6-4A2C-882E-6D57AD3D37E5}']
    procedure Dispose;
  end;

  ICancelable = interface(IDisposable)
    function GetIsDisposed: Boolean;
    property IsDisposed: Boolean read GetIsDisposed;
  end;

  ICompositeDisposable = interface(ICancelable)
    function GetCount: Integer;
    procedure Add(const item: IDisposable);
    function Remove(const item: IDisposable): Boolean;
    property Count: Integer read GetCount;
  end;

  IRefCountDisposable = interface(ICancelable)
    function GetDisposable: IDisposable;
  end;

  ISerialDisposable = interface(ICancelable)
    function GetDisposable: IDisposable;
    procedure SetDisposable(const value: IDisposable);
    property Disposable: IDisposable read GetDisposable write SetDisposable;
  end;

  ISingleAssignmentDisposable = interface(ICancelable)
    function GetDisposable: IDisposable;
    procedure SetDisposable(const value: IDisposable);
    property Disposable: IDisposable read GetDisposable write SetDisposable;
  end;

  TDisposableObject = class(TInterfacedObject, IDisposable)
  private
    fIsDisposed: Boolean;
  public
    procedure Dispose; virtual;
    property IsDisposed: Boolean read fIsDisposed;
  end;

  {$ENDREGION}

  IStopwatch = interface
    function GetElapsed: TTimeSpan;
    property Elapsed: TTimeSpan read GetElapsed;
  end;

  IStopwatchProvider = interface
    function StartStopwatch: IStopwatch;
  end;

  IConcurrencyAbstractionLayer = interface
    /// <summary>
    ///   Queues a method for execution at the specified relative time.
    /// </summary>
    /// <param name="action">
    ///   Method to execute.
    /// </param>
    /// <param name="state">
    ///   State to pass to the method.
    /// </param>
    /// <param name="dueTime">
    ///   Time to execute the method on.
    /// </param>
    /// <returns>
    ///   Disposable object that can be used to stop the timer.
    /// </returns>
    function StartTimer(const action: Action<TValue>; const state: TValue; const dueTime: TTimeSpan): IDisposable;

    /// <summary>
    ///   Queues a method for periodic execution based on the specified period.
    /// </summary>
    /// <param name="action">
    ///   Method to execute; should be safe for reentrancy.
    /// </param>
    /// <param name="period">
    ///   Period for running the method periodically.
    /// </param>
    /// <returns>
    ///   Disposable object that can be used to stop the timer.
    /// </returns>
    function StartPeriodicTimer(const action: Action; const period: TTimeSpan): IDisposable;

    /// <summary>
    ///   Queues a method for execution.
    /// </summary>
    /// <param name="action">
    ///   Method to execute.
    /// </param>
    /// <param name="state">
    ///   State to pass to the method.
    /// </param>
    /// <returns>
    ///   Disposable object that can be used to cancel the queued method.
    /// </returns>
    function QueueUserWorkItem(const action: Action<TValue>; const state: TValue): IDisposable;

    /// <summary>
    ///   Blocking sleep operation.
    /// </summary>
    /// <param name="timeout">
    ///   Time to sleep.
    /// </param>
    procedure Sleep(const timeout: TTimeSpan);

    /// <summary>
    ///   Starts a new stopwatch object.
    /// </summary>
    /// <returns>
    ///   New stopwatch object; started at the time of the request.
    /// </returns>
    function StartStopwatch: IStopwatch;

    /// <summary>
    ///   Gets whether long-running scheduling is supported.
    /// </summary>
    function SupportsLongRunning: Boolean;

    /// <summary>
    ///   Starts a new long-running thread.
    /// </summary>
    /// <param name="action">
    ///   Method to execute.
    /// </param>
    /// <param name="state">
    ///   State to pass to the method.
    /// </param>
    procedure StartThread(const action: Action<TValue>; const state: TValue);
  end;

  IScheduler = interface
    ['{61722BD1-AD2B-4B8C-A95A-A0A612FEEE8A}']
    // methods to be implemented
    function GetNow: TDateTime; // consider changing to TDateTimeOffset (which includes UTC offset)
    function Schedule(const state: TValue;
      const action: Func<IScheduler, TValue, IDisposable>): IDisposable; overload;
    function Schedule(const state: TValue; const dueTime: TTimeSpan;
      const action: Func<IScheduler, TValue, IDisposable>): IDisposable; overload;
    property Now: TDateTime read GetNow;

    // extension methods from Scheduler.Simple.cs
    function Schedule(const action: Action): IDisposable; overload;
    function Schedule(const dueTime: TTimeSpan; const action: Action): IDisposable; overload;

    // extension methods from Scheduler.Recursive.cs
    function Schedule(const action: Action<Action>): IDisposable; overload;
    function Schedule(const state: TValue;
      const action: Action<TValue, Action<TValue>>): IDisposable; overload;
    function Schedule(const dueTime: TTimeSpan;
      const action: Action<Action<TTimeSpan>>): IDisposable; overload;
    function Schedule(const state: TValue; const dueTime: TTimeSpan;
      const action: Action<TValue, Action<TValue, TTimeSpan>>): IDisposable; overload;
  end;

  ISchedulerPeriodic = interface(IScheduler)
    ['{9B55DD0F-2B7E-4CFB-A95B-3D6F673E8036}']
    function SchedulePeriodic(const period: TTimeSpan; const action: Action): IDisposable; overload;

    function SchedulePeriodic(const state: TValue; const period: TTimeSpan; const action: Func<TValue, TValue>): IDisposable; overload;
  end;

  IObserver<T> = interface(IDisposable)
    ['{3E391579-B8FE-41AB-99E4-B2BCAFAB2410}']
    procedure OnNext(const value: T);
    procedure OnError(const error: Exception);
    procedure OnCompleted;
  end;

//  IObservableExtensions<T> = class;

  IObservable<T> = interface(IDisposable)
    ['{E20F7E99-4952-47A3-8F02-8F37972C0E5D}']
    function Subscribe(const observer: IObserver<T>): IDisposable; overload;

    // "extension" methods - they redirect to Subscribe(IObserver<T>)
    function Subscribe: IDisposable; overload;
    function Subscribe(const onNext: Action<T>): IDisposable; overload;
    function Subscribe(const onNext: Action<T>;
      const onError: Action<Exception>): IDisposable; overload;
    function Subscribe(const onNext: Action<T>;
      const onCompleted: Action): IDisposable; overload;
    function Subscribe(const onNext: Action<T>;
      const onError: Action<Exception>;
      const onCompleted: Action): IDisposable; overload;


    // "extension" methods for reducing
    function Distinct: IObservable<T>;
    function DistinctUntilChanged: IObservable<T>;
    function IgnoreElements: IObservable<T>;
    function Sample(const interval: TTimeSpan): IObservable<T>;
    function Skip(count: Integer): IObservable<T>;
    function SkipLast(count: Integer): IObservable<T>;
    function SkipWhile(const predicate: Predicate<T>): IObservable<T>; overload;
    function SkipWhile(const predicate: Func<T, Integer, Boolean>): IObservable<T>; overload;

//    function StartWith(const values: array of T): IObservable<T>; overload;
//    function StartWith(const values: IEnumerable<T>): IObservable<T>; overload;
    // TODO overloads with scheduler

    function Take(count: Integer): IObservable<T>;
    function TakeLast(count: Integer): IObservable<T>;
    function TakeWhile(const predicate: Predicate<T>): IObservable<T>; overload;
    function TakeWhile(const predicate: Func<T, Integer, Boolean>): IObservable<T>; overload;
    function Throttle(const dueTime: TTimeSpan): IObservable<T>;
    function Where(const predicate: Predicate<T>): IObservable<T>;

    // "extension" methods for inspecting
    function All(const predicate: Predicate<T>): IObservable<Boolean>;
    function Any: IObservable<Boolean>; overload;
    function Any(const predicate: Predicate<T>): IObservable<Boolean>; overload;

    // "extension" methods for aggregating
    function Concat(const second: IObservable<T>): IObservable<T>;


    procedure ForEach(const onNext: Action<T>);

    // TODO PPL overloads / cancellation token

    // experimental - extension support - does not work, causes the compiler to hang
//    function _: IObservableExtensions<T>;
  end;

  IGroupedObservable<TKey, TElement> = interface(IObservable<TElement>)
    ['{C521C380-692D-49BE-9E3F-9E6037C2D066}']
    function GetKey: TKey;
    property Key: TKey read GetKey;
  end;

  ISubject<T> = interface(IObservable<T>)
    procedure OnNext(const value: T);
    procedure OnError(const error: Exception);
    procedure OnCompleted;
  end;

  ISubject<TSource, TResult> = interface(IObservable<TResult>{, IObserver<TSource>})
    // from IObserver<TSource>
    procedure OnNext(const value: TSource);
    procedure OnError(const error: Exception);
    procedure OnCompleted;
  end;

  TInterlocked = SyncObjs.TInterlocked;
  TInterlockedHelper = class helper for TInterlocked // TODO: move to Spring.pas
    class function CompareExchange<T: IInterface>(var Target: T; const Value, Comparand: T): T; overload;
    class function Exchange<T: IInterface>(var Target: T; const Value: T): T; overload;
  end;

  TArrayHelper = class helper for TArray // TODO: move to Spring.pas
    class function Add<T>(const items: TArray<T>; const item: T): TArray<T>; static;
    class function Remove<T>(const items: TArray<T>; const item: T): TArray<T>; static;
  end;

  TObservable = record
    class function Timer(const dueTime, period: TTimeSpan; const scheduler: IScheduler): IObservable<Integer>; static;
  public
    class function Buffer<T>(const source: IObservable<T>; count: Integer): IObservable<IList<T>>; overload; static;
    class function Buffer<T>(const source: IObservable<T>; count, skip: Integer): IObservable<IList<T>>; overload; static;
    class function Buffer<T>(const source: IObservable<T>; const timeSpan: TTimeSpan): IObservable<IList<T>>; overload; static;

    class function Buffer<TSource, TBufferClosing>(const source: IObservable<TSource>;
      const bufferClosingSelector: Func<IObservable<TBufferClosing>>): IObservable<IList<TSource>>; overload; static;
    class function Buffer<TSource, TBufferBoundary>(const source: IObservable<TSource>;
      const bufferBoundaries: IObservable<TBufferBoundary>): IObservable<IList<TSource>>; overload; static;

    class function CombineLatest<TFirst, TSecond, TResult>(
      const first: IObservable<TFirst>;
      const second: IObservable<TSecond>;
      const resultSelector: Func<TFirst, TSecond, TResult>): IObservable<TResult>; static;

    class function Create<T>(const subscribe: Func<IObserver<T>, IDisposable>): IObservable<T>; static;

    class function Empty<T>: IObservable<T>; static;

    class function From<T>(const source: array of T): IObservable<T>; static;

//    class function Generate<TState,TResult>(const initialState: TState;
//      const condition: Func<TState, Boolean>;
//      const iterate: Func<TState, TState>;
//      const resultSelector: Func<TState, TResult>): IObservable<TResult>; static;

    class function GroupBy<TSource, TKey>(const source: IObservable<TSource>;
      const keySelector: Func<TSource, TKey>): IObservable<IGroupedObservable<TKey, TSource>>; static;
    // TODO overloads

    class function Interval(const period: TTimeSpan): IObservable<Integer>; static;

    class function Merge<T>(const sources: array of IObservable<T>): IObservable<T>; overload; static;
    class function Merge<T>(const sources: IObservable<IObservable<T>>): IObservable<T>; overload; static;

    class function Never<T>: IObservable<T>; static;

    class function Range(start, count: Integer): IObservable<Integer>; static;

    class function Return<T>(const value: T): IObservable<T>; static;

    class function Select<TSource, TResult>(const source: IObservable<TSource>; const selector: Func<TSource, TResult>): IObservable<TResult>; overload; static;
//    class function Select<TSource, TResult>(const source: IObservable<TSource>; const selector: Func<TSource, Integer, TResult>): IObservable<TResult>; overload; static;

    class function SkipUntil<TSource, TOther>(const source: IObservable<TSource>; const other: IObservable<TOther>): IObservable<TSource>; static;

    class function TakeUntil<TSource, TOther>(const source: IObservable<TSource>; const other: IObservable<TOther>): IObservable<TSource>; static;

    class function Throw<T>(const error: Exception): IObservable<T>; static;

    class function Window<T>(const source: IObservable<T>; count: Integer): IObservable<IObservable<T>>; static;

    // TODO Timer

    // events
  {$IFDEF DELPHIXE2_UP}
    class function FromEventPattern<T>(const target: TComponent; const eventName: string): IObservable<T>; static;
  {$ENDIF}
  end;

  Enumerable = record
  public
    class function Subscribe<T>(const source: IEnumerable<T>; const observer: IObserver<T>): IDisposable; static;
    class function ToObservable<T>(const source: array of T): IObservable<T>; overload; static;
    class function ToObservable<T>(const source: IEnumerable<T>): IObservable<T>; overload; static;
  end;

  EObjectDisposedException = class(EInvalidOperationException); // TODO: move to Spring.pas

//  IObservableExtensions<T> = class
//  public
//    function Buffer<TBufferBoundary>(const bufferBoundaries: IObservable<TBufferBoundary>): IObservable<IList<T>>; overload;
//    function Select<TResult>(const selector: Func<T, TResult>): IObservable<TResult>; overload;
//  end;

type
  TEventWrapper<TArgs> = class(TComponent) // TODO: move into own unit once properly implemented
  private
    fRemoveHandler: Action;
  public
    destructor Destroy; override;
    property RemoveHandler: Action read fRemoveHandler write fRemoveHandler;
  end;

implementation

uses
  Generics.Defaults,
  Spring.Reactive.AnonymousObservable,
  Spring.Reactive.Concurrency.SchedulerDefaults,
  Spring.Reactive.Internal.Stubs,
  Spring.Reactive.Observable.Buffer,
  Spring.Reactive.Observable.CombineLatest,
  Spring.Reactive.Observable.Empty,
  Spring.Reactive.Observable.GroupBy,
  Spring.Reactive.Observable.Merge,
  Spring.Reactive.Observable.Never,
  Spring.Reactive.Observable.Range,
  Spring.Reactive.Observable.Return,
  Spring.Reactive.Observable.Select,
  Spring.Reactive.Observable.SkipUntil,
  Spring.Reactive.Observable.TakeUntil,
  Spring.Reactive.Observable.Throw,
  Spring.Reactive.Observable.Timer,
  Spring.Reactive.Observable.ToObservable,
  Spring.Reactive.Observable.Window,
  Spring.Reactive.Subjects.Subject; // TODO: remove - implement this specifically


{$REGION 'IObservableExtensions<T>'}

//function IObservableExtensions<T>.Buffer<TBufferBoundary>(
//  const bufferBoundaries: IObservable<TBufferBoundary>): IObservable<IList<T>>;
//begin
//  Result := TBuffer<T, TBufferBoundary>.Create(TInterfacedObject(Self) as IObservable<T>, bufferBoundaries);
//end;

//function IObservableExtensions<T>.Select<TResult>(
//  const selector: Func<T, TResult>): IObservable<TResult>;
//begin
//  Result := TSelect<T, TResult>.Create(TInterfacedObject(Self) as IObservable<T>, selector);
//end;

{$ENDREGION}


{$REGION 'TDisposableObject'}

procedure TDisposableObject.Dispose;
begin
  fIsDisposed := True;
end;

{$ENDREGION}


{$REGION 'TTimeSpanHelper'}

class function TTimeSpanHelper.&&op_Implicit(const value: Double): TTimeSpan;
begin
  Result := TTimeSpan.FromMilliseconds(value);
end;

{$ENDREGION}


{$REGION 'TThreadHelper'}

function TThreadHelper.GetTerminated: Boolean;
begin
  Result := inherited Terminated;
end;

class procedure TThreadHelper.Sleep(const timeout: TTimeSpan);
begin
  TThread.Sleep(Trunc(timeout.TotalMilliseconds));
end;

{$ENDREGION}


{$REGION 'TInterlockedHelper'}

class function TInterlockedHelper.CompareExchange<T>(var Target: T;
  const Value, Comparand: T): T;
begin
  Result := Default(T);
  PPointer(@Result)^ := inherited CompareExchange(PPointer(@Target)^, PPointer(@Value)^, PPointer(@Comparand)^);
  if PPointer(@Result)^ = PPointer(@Comparand)^ then
  begin
    if Assigned(Value) then
      Value._AddRef;
  end
  else
    if Assigned(Result) then
      Result._AddRef;
end;

class function TInterlockedHelper.Exchange<T>(var Target: T;
  const Value: T): T;
begin
  Result := Default(T);
  PPointer(@Result)^ := inherited Exchange(PPointer(@Target)^, PPointer(@Value)^);
  if Assigned(Value) then
    Value._AddRef;
end;

{$ENDREGION}


{$REGION 'TArrayHelper'}

class function TArrayHelper.Add<T>(const items: TArray<T>;
  const item: T): TArray<T>;
var
  n: Integer;
begin
//  Result := items + [item];
  Result := items;
  n := Length(Result);
  SetLength(Result, n + 1);
  Result[n] := item;
end;

class function TArrayHelper.Remove<T>(const items: TArray<T>;
  const item: T): TArray<T>;
var
  i: Integer;
begin
  i := TArray.IndexOf<T>(items, item);
  if i < 0 then
    Exit(items);
  if Length(items) = 1 then
    Exit(nil);
//  Result := System.Copy(items, 0, i) + System.Copy(items, i + 1);
  Result := TArray.Concat<T>([System.Copy(items, 0, i), System.Copy(items, i + 1)]);
end;

{$ENDREGION}


{$REGION 'Observable'}

class function TObservable.Buffer<T>(const source: IObservable<T>;
  count: Integer): IObservable<IList<T>>;
begin
  Result := TBuffer<T>.Create(source, count, count);
end;

class function TObservable.Buffer<T>(const source: IObservable<T>; count,
  skip: Integer): IObservable<IList<T>>;
begin
  Result := TBuffer<T>.Create(source, count, skip);
end;

class function TObservable.Buffer<T>(const source: IObservable<T>;
  const timeSpan: TTimeSpan): IObservable<IList<T>>;
begin
  Result := TBuffer<T>.Create(source, timeSpan, timeSpan, SchedulerDefaults.TimeBasedOperations);
end;

class function TObservable.Buffer<TSource, TBufferClosing>(
  const source: IObservable<TSource>;
  const bufferClosingSelector: Func<IObservable<TBufferClosing>>): IObservable<IList<TSource>>;
begin
  Result := TBuffer<TSource, TBufferClosing>.Create(source, bufferClosingSelector);
end;

class function TObservable.Buffer<TSource, TBufferBoundary>(
  const source: IObservable<TSource>;
  const bufferBoundaries: IObservable<TBufferBoundary>): IObservable<IList<TSource>>;
begin
  Result := TBuffer<TSource, TBufferBoundary>.Create(source, bufferBoundaries);
end;

class function TObservable.CombineLatest<TFirst, TSecond, TResult>(
  const first: IObservable<TFirst>; const second: IObservable<TSecond>;
  const resultSelector: Func<TFirst, TSecond, TResult>): IObservable<TResult>;
begin
  Result := TCombineLatest<TFirst, TSecond, TResult>.Create(first, second, resultSelector);
end;

class function TObservable.Create<T>(
  const subscribe: Func<IObserver<T>, IDisposable>): IObservable<T>;
begin
  Result := TAnonymousObservable<T>.Create(subscribe);
end;

class function TObservable.Empty<T>: IObservable<T>;
begin
  Result := TEmpty<T>.Create(SchedulerDefaults.ConstantTimeOperations);
end;

class function TObservable.From<T>(const source: array of T): IObservable<T>;
begin
  Result := Enumerable.ToObservable<T>(TEnumerable.From<T>(source));
end;

{$IFDEF DELPHIXE2_UP}
class function TObservable.FromEventPattern<T>(const target: TComponent;
  const eventName: string): IObservable<T>;
var
  event: TRttiProperty;
  fields: TArray<TRttiField>;
  args: TArray<TRttiParameter>;
  i: Integer;
  getResult: Func<TArray<TValue>,T>;

  m: TMethod;
  handler: TValue;

  obs: ISubject<T>;
  wrapper: TEventWrapper<T>;
begin
  event := TType.GetType(target.ClassInfo).GetProperty(eventName);
  args := (event.PropertyType as TRttiInvokableType).GetParameters;
  fields := TType.GetType(TypeInfo(T)).GetFields;

  Assert(Length(fields) = Length(args));
  for i := 0 to High(fields) do
    Assert(fields[i].FieldType.Handle = args[i].ParamType.Handle);

  getResult :=
    function(const args: TArray<TValue>): T
    var
      i: Integer;
    begin
      for i := 0 to High(fields) do
        fields[i].SetValue(@Result, Args[i+1]);
    end;

  m := TRttiInvokableType(event.PropertyType).CreateImplementation(nil,
    procedure(UserData: Pointer; const Args: TArray<TValue>; out Result: TValue)
    begin
      obs.OnNext(getResult(Args));
    end).AsMethod;
  TValue.Make(@m, event.PropertyType.Handle, handler);
  event.SetValue(target, handler);

  obs := TSubject<T>.Create;

  wrapper := TEventWrapper<T>.Create(target);
  wrapper.RemoveHandler :=
    procedure
    begin
      obs.OnCompleted;
      obs.Dispose;

      event.SetValue(target, nil);
      FreeAndNil(m.Data);
      getResult := nil;
      obs := nil;
    end;

  Result := obs;
end;
{$ENDIF}

//class function Observable.Generate<TState, TResult>(const initialState: TState;
//  const condition: Func<TState, Boolean>; const iterate: Func<TState, TState>;
//  const resultSelector: Func<TState, TResult>): IObservable<TResult>;
//begin
//  Result := TGenerate<TState, TResult>.Create(
//    initialState, condition, iterate, resultSelector);
//end;

class function TObservable.GroupBy<TSource, TKey>(
  const source: IObservable<TSource>;
  const keySelector: Func<TSource, TKey>): IObservable<IGroupedObservable<TKey, TSource>>;
begin
  Result := TGroupBy<TSource, TKey, TSource>.Create(source, keySelector,
    function(const x: TSource): TSource begin Result := x; end, 0, TEqualityComparer<TKey>.Default);
end;

class function TObservable.Interval(const period: TTimeSpan): IObservable<Integer>;
begin
  Result := Timer(period, period, SchedulerDefaults.TimeBasedOperations);
end;

class function TObservable.Merge<T>(
  const sources: array of IObservable<T>): IObservable<T>;
begin
  Result := Merge<T>(Enumerable.ToObservable<IObservable<T>>(sources));
end;

class function TObservable.Merge<T>(
  const sources: IObservable<IObservable<T>>): IObservable<T>;
begin
  Result := TMerge<T>.Create(sources);
end;

class function TObservable.Never<T>: IObservable<T>;
begin
  Result := TNever<T>.Create;
end;

class function TObservable.Range(start, count: Integer): IObservable<Integer>;
begin
  Result := TRange.Create(start, count, SchedulerDefaults.Iteration);
end;

class function TObservable.Return<T>(const value: T): IObservable<T>;
begin
  Result := TReturn<T>.Create(value, SchedulerDefaults.ConstantTimeOperations);
end;

class function TObservable.Select<TSource, TResult>(
  const source: IObservable<TSource>;
  const selector: Func<TSource, TResult>): IObservable<TResult>;
begin
  Result := TSelect<TSource, TResult>.Create(source, selector);
end;

class function TObservable.SkipUntil<TSource, TOther>(
  const source: IObservable<TSource>;
  const other: IObservable<TOther>): IObservable<TSource>;
begin
  Result := TSkipUntil<TSource, TOther>.Create(source, other);
end;

class function TObservable.TakeUntil<TSource, TOther>(
  const source: IObservable<TSource>;
  const other: IObservable<TOther>): IObservable<TSource>;
begin
  Result := TTakeUntil<TSource, TOther>.Create(source, other);
end;

class function TObservable.Throw<T>(const error: Exception): IObservable<T>;
begin
  Result := TThrow<T>.Create(error, SchedulerDefaults.ConstantTimeOperations);
end;

class function TObservable.Timer(const dueTime, period: TTimeSpan;
  const scheduler: IScheduler): IObservable<Integer>;
begin
  Result := TTimer.Create(dueTime, period, scheduler);
end;

class function TObservable.Window<T>(const source: IObservable<T>;
  count: Integer): IObservable<IObservable<T>>;
begin
  Result := TWindow<T>.Create(source, count, count);
end;

{$ENDREGION}


{$REGION 'Enumerable'}

class function Enumerable.Subscribe<T>(const source: IEnumerable<T>;
  const observer: IObserver<T>): IDisposable;
begin
  Result := TToObservable<T>.Create(source, SchedulerDefaults.Iteration).Subscribe(observer);
end;

class function Enumerable.ToObservable<T>(
  const source: array of T): IObservable<T>;
begin
  Result := TToObservable<T>.Create(TEnumerable.From<T>(source), SchedulerDefaults.Iteration);
end;

class function Enumerable.ToObservable<T>(
  const source: IEnumerable<T>): IObservable<T>;
begin
  Result := TToObservable<T>.Create(source, SchedulerDefaults.Iteration);
end;

{$ENDREGION}


{$REGION 'TEventWrapper<TArgs>'}

destructor TEventWrapper<TArgs>.Destroy;
begin
  if Assigned(fRemoveHandler) then
  begin
    fRemoveHandler;
    fRemoveHandler := nil;
  end;
  inherited;
end;

{$ENDREGION}


end.