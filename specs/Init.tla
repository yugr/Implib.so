---- MODULE Init ----

(*
  TODO:
  - allow nested function calls ?
*)

EXTENDS
  Integers, FiniteSets, Sequences, TLC

CONSTANTS
  THREADS, FUNS, CALLS, MAX_DEPTH, MAX_LOCK

ASSUME
  /\ Cardinality(FUNS) > 0
  /\ CALLS \in Nat
  /\ MAX_DEPTH \in Nat \ {0}

NoThread == CHOOSE t : t \notin THREADS

VARIABLES
  threads, shim_table, lib_handle_set, lib_state, rec_lock

\* STATES

PC == {
  (* Driver program *) "START", "DRIVER",
  (* At start of interceptor *) "SHIM_START",
  (* In real function *) "FUNC_START", "FUNC_END",
  (* At start of resolver *) "RESOLVER_START",
  (* After locking mutex *) "LOCKED",
  (* Inside dlopen and global ctor *) "DLOPENING",
  (* After dlopen, before writing lib_handle *) "DLOPENED",
  (* After writing lib_handle *) "WROTE_HANDLE",
  (* After dlsym *) "RESOLVED",
  (* At end of resolver *) "UNLOCKED"
}

LibraryState == {
  "UNLOADED", "LOADING", "LOADED"
}

Callees == FUNS \union {""}

StackFrame == [pc : PC, calls : 0..CALLS, callee : Callees]

CallStack == UNION {[1..len -> StackFrame] : len \in 0..MAX_DEPTH}


\* HELPERS

Last(s) == s[Len(s)]

Goto(t, pc) == [threads EXCEPT ![t] = [
  @ EXCEPT ![Len(@)] = [
    @ EXCEPT !.pc = pc]
  ]
]

\* INVARIANTS AND PROPERTIES

TypeInvariant ==
  /\ threads \in [THREADS -> CallStack]
  /\ shim_table \in [FUNS -> BOOLEAN]
  /\ lib_handle_set \in BOOLEAN
  /\ lib_state \in LibraryState
  /\ rec_lock \in [owner : THREADS \union {NoThread}, count : 0..MAX_LOCK]

LockInvariant ==
  /\
    \/ (rec_lock.owner = NoThread /\ rec_lock.count = 0)
    \/ (rec_lock.owner # NoThread /\ rec_lock.count > 0)
  /\
    \A t \in THREADS :
      \/ Len(threads[t]) = 0
      \/ Last(threads[t]).pc \in {"LOCKED", "DLOPENING", "DLOPENED", "WROTE_HANDLE", "RESOLVED"} => rec_lock.owner = t

\* Library must be initialized before clients can call any of its functions via fast path
LoadBeforeUse ==
  \A f \in FUNS : shim_table[f] => lib_state = "LOADED"
LoadBeforeUse2 ==
  \A t \in THREADS :
    \/ Len(threads[t]) = 0
    \/ Last(threads[t]).pc = "FUNC_START" => lib_state \in (IF Len(threads[t]) > 1 THEN {"LOADING", "LOADED"} ELSE {"LOADED"})

\* Library handle set only if library is loaded (not necessarily initialized)
LibHandleCorrectness == lib_handle_set => lib_state \in {"LOADING", "LOADED"}

\* All threads terminate, lock is released and library is loaded
Termination == <>[]
  /\ \A t \in THREADS : Len(threads[t]) = 0
  /\ rec_lock.owner = NoThread /\ rec_lock.count = 0
  /\ lib_state = "LOADED" /\ lib_handle_set

\* Library never UN-loaded
NoLibResets ==
  [][
    /\ lib_state = "LOADING" => lib_state' \in {"LOADING", "LOADED"}
    /\ lib_state = "LOADED" => lib_state' = "LOADED"
  ]_lib_state

\* Shims are never reset
NoShimResets ==
  [][
    \A f \in FUNS : shim_table[f] => shim_table'[f]
  ]_shim_table

\* SPECIFICATION

Init ==
  /\ threads = [t \in THREADS |-> <<[pc |-> "START", calls |-> CALLS, callee |-> ""]>>]
  /\ shim_table = [f \in FUNS |-> FALSE]
  /\ lib_handle_set = FALSE
  /\ lib_state = "UNLOADED"
  /\ rec_lock = [owner |-> NoThread, count |-> 0]

\* Thread starts execution
Start(t) ==
  /\ Last(threads[t]).pc = "START"
  /\ threads' = Goto(t, "DRIVER")
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state, rec_lock>>

\* Thread calls shim
Call(t) ==
  /\ Last(threads[t]).pc = "DRIVER"
  /\ Last(threads[t]).calls > 0
  /\ \E f \in FUNS :
    /\ threads' = [threads EXCEPT ![t] = [
        @ EXCEPT ![Len(@)] = [
          pc |-> "SHIM_START", calls |-> @.calls - 1, callee |-> f]
        ]
      ]
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state, rec_lock>>

\* Shim is already resolved so call real function
FastPath(t) ==
  /\ Last(threads[t]).pc = "SHIM_START"
  /\ shim_table[Last(threads[t]).callee]
  /\ threads' = Goto(t, "FUNC_START")
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state, rec_lock>>

\* Shim is unresolved so goto resolver
SlowPath(t) ==
  /\ Last(threads[t]).pc = "SHIM_START"
  /\ ~shim_table[Last(threads[t]).callee]
  /\ threads' = Goto(t, "RESOLVER_START")
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state, rec_lock>>

\* Enter critical section
Lock(t) ==
  /\ Last(threads[t]).pc = "RESOLVER_START"
  /\ (rec_lock.owner = t \/ rec_lock.count = 0)
  /\ threads' = Goto(t, "LOCKED")
  /\ rec_lock' = [owner |-> t, count |-> rec_lock.count + 1]
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state>>

\* Load library after handle is already set (simplest case)
LoadLibrarySimple(t) ==
  /\ Last(threads[t]).pc = "LOCKED"
  /\ lib_handle_set
  /\ threads' = Goto(t, "RESOLVED")
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state, rec_lock>>

\* Load library for the first time, running global ctors
LoadLibraryFirstTime(t) ==
  /\ Last(threads[t]).pc = "LOCKED"
  /\ ~lib_handle_set
  /\ lib_state = "UNLOADED"
  /\ threads' = [threads EXCEPT ![t] = Append(
      [@ EXCEPT ![Len(@)] = [@ EXCEPT !.pc = "DLOPENING"]],
      [pc |-> "DRIVER", calls |-> CALLS, callee |-> ""]
    )]
  /\ lib_state' = "LOADING"
  /\ UNCHANGED <<shim_table, lib_handle_set, rec_lock>>

\* Initialize library
\* TODO: LOADED may be set before DLOPENED
InitializeLibrary(t) ==
  /\ Last(threads[t]).pc = "DLOPENING"
  /\ lib_state = "LOADING"
  /\ threads' = Goto(t, "DLOPENED")
  /\ lib_state' = "LOADED"
  /\ UNCHANGED <<shim_table, lib_handle_set, rec_lock>>

\* Load library after loaded but before handle is set
\* Note that this corresponds to two cases: 1) library still initializing, 2) library initialized
LoadLibraryRecursive(t) ==
  /\ Last(threads[t]).pc = "LOCKED"
  /\ ~lib_handle_set
  /\ lib_state \in {"LOADING", "LOADED"}
  /\ threads' = Goto(t, "DLOPENED")
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state, rec_lock>>

\* Set lib_handle
WriteHandle(t) ==
  /\ Last(threads[t]).pc = "DLOPENED"
  /\ threads' = Goto(t, "WROTE_HANDLE")
  /\ lib_handle_set' = TRUE
  /\ UNCHANGED <<shim_table, lib_state, rec_lock>>

\* Resolve symbol
Resolve(t) ==
  /\ Last(threads[t]).pc = "WROTE_HANDLE"
  /\ threads' = Goto(t, "RESOLVED")
  \* We publish only in first call (this is imprecise but ok for now)
  /\ shim_table' = IF rec_lock.count > 1 THEN shim_table ELSE [shim_table EXCEPT ![Last(threads[t]).callee] = TRUE]
  /\ UNCHANGED <<lib_handle_set, lib_state, rec_lock>>

\* Exit critical section
Unlock(t) ==
  /\ Last(threads[t]).pc = "RESOLVED"
  /\ threads' = Goto(t, "UNLOCKED")
  /\ rec_lock' = IF rec_lock.count = 1 THEN [owner |-> NoThread, count |-> 0] ELSE [owner |-> rec_lock.owner, count |-> rec_lock.count - 1]
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state>>

\* Call after resolution
ReCall(t) ==
  /\ Last(threads[t]).pc = "UNLOCKED"
  /\ threads' = Goto(t, "FUNC_START")
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state, rec_lock>>

\* Thread returns from function
Return(t) ==
  /\ Last(threads[t]).pc = "FUNC_START"
  /\ threads' = [threads EXCEPT ![t] = [
      @ EXCEPT ![Len(@)] = [
        @ EXCEPT !.pc = "DRIVER", !.callee = ""]
      ]
    ]
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state, rec_lock>>

\* Thread returns
PopFrame(t) ==
  /\ Last(threads[t]).pc = "DRIVER"
  /\ Last(threads[t]).calls = 0
  /\ threads' = [threads EXCEPT ![t] = SubSeq(@, 1, Len(@) - 1)]
  /\ UNCHANGED <<shim_table, lib_handle_set, lib_state, rec_lock>>

\* Program completes
Stop ==
  /\ \A t \in THREADS : Len(threads[t]) = 0
  /\ UNCHANGED <<threads, shim_table, lib_handle_set, lib_state, rec_lock>>

Next ==
  \/ \E t \in THREADS :
    /\ Len(threads[t]) > 0
    /\ \/ Start(t)
       \/ Call(t)
         \/ FastPath(t)
         \/ SlowPath(t)
           \/ Lock(t)
           \/ LoadLibrarySimple(t) \/ LoadLibraryFirstTime(t) \/ InitializeLibrary(t) \/ LoadLibraryRecursive(t) \/ WriteHandle(t)
           \/ Resolve(t) \/ Unlock(t) \/ ReCall(t)
       \/ Return(t)
       \/ PopFrame(t)
  \/ Stop

Spec ==
  /\ Init
  /\ [][Next]_<<threads, shim_table, lib_handle_set, lib_state, rec_lock>>
  /\ WF_<<threads>>(Next)

======================================================================
