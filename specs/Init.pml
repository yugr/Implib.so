// TODO:
// - allow nested function calls ?
// - can we get rid of XXX_LOG2 ?

// SPIN issues:
// - not printing local variables in traces
// - no functions
// - dedicated run for each LTL property

#define INIT

// Number of concurrent threads
#define THREADS 2
#define THREADS_LOG2 2
#if THREADS >= (1 << THREADS_LOG2)
# error Increase THREADS_LOG2
#endif

#define NO_THREAD 0

// Number of library functions
#define FUNS 2
#define FUNS_LOG2 2
#if FUNS >= (1 << FUNS_LOG2)
# error Increase FUNS_LOG2
#endif

#define NO_FUN 0

// Number of calls in each thread and in library ctor
#define CALLS 2
#define CALLS_LOG2 2
#if CALLS >= (1 << CALLS_LOG2)
# error Increase CALLS_LOG2
#endif

// Max callstack size
#define MAX_DEPTH 2
#define MAX_DEPTH_LOG2 2
#if MAX_DEPTH >= (1 << MAX_DEPTH_LOG2)
# error Increase MAX_DEPTH_LOG2
#endif

// Max number of recursive mutex locks
#define MAX_LOCK 4
#define MAX_LOCK_LOG2 2
#if MAX_LOCK > (1 << MAX_LOCK_LOG2)
# error Increase MAX_LOCK_LOG2
#endif

// Sanity checks
#if THREADS <= 0 || FUNS <= 0 || CALLS <= 0 || MAX_DEPTH <= 0 || MAX_LOCK <= 0
# error Invalid config
#endif

// Types

// LibraryState
// TODO: is this an abuse of mtype and I should switch to macro instead?
mtype {
  UNLOADED, LOADING, LOADED
}

typedef Lock {
  unsigned owner : THREADS_LOG2
  unsigned count : MAX_DEPTH_LOG2
}

typedef StackFrame {
  unsigned calls : CALLS_LOG2
  unsigned callee : FUNS_LOG2
}

typedef CallStack {
  StackFrame frames[MAX_DEPTH]
  unsigned n : MAX_DEPTH_LOG2
}

// Global state

bit shim_table[FUNS]
bit lib_handle_set
mtype lib_state
Lock rec_lock

int terminated

// Code

proctype Thread(int tid) {
  CallStack stack

  stack.n = 1
  stack.frames[0].calls = CALLS
  stack.frames[0].callee = NO_FUN

recurse:
  do
    // Thread completed => terminate
    :: stack.n == 0 -> break

    // Thread still active
    :: else -> {  // L.run
      if
        // No more functions to call
        :: stack.frames[stack.n - 1].calls == 0 -> {
          stack.n--
#ifdef INIT
          if
            // We are in top frame
            :: stack.n == 0 -> skip

            // We have finished library init, return to caller
            :: else -> {
              lib_state = LOADED
              goto return_from_recurse
            }
          fi
#endif
        }

        // Some functions left
        :: else -> {  // L.call
          int fun
          select(fun : 1 .. FUNS)

          stack.frames[stack.n - 1].calls--
          stack.frames[stack.n - 1].callee = fun

          if
            // Fast path
            :: shim_table[fun - 1] -> {
              // LoadBeforeUse(TLA): Library must be initialized before clients can call any of its functions via fast path
              assert(lib_state == LOADED)
              skip
            }

            // Slow path
            :: else -> {  // L.slow

              // Enter critical section

              atomic {
                rec_lock.owner == NO_THREAD || rec_lock.owner == tid
                assert(rec_lock.owner == NO_THREAD || rec_lock.count > 0)
                rec_lock.owner = tid
                rec_lock.count++
              }

              // Obtain library handle

              if
                // Handle is already set (simplest case) ?
                :: lib_handle_set -> skip

                // Load library after it's already loaded but before handle is set
                // There are 2 cases: 1) library still initializing, 2) library initialized
                :: !lib_handle_set && (lib_state == LOADING || lib_state == LOADED) -> {
                  lib_handle_set = true
                }

                // Load library for the first time, running global ctors
                :: !lib_handle_set && lib_state == UNLOADED -> {
                  // Initialize library

#ifdef INIT
                  lib_state = LOADING

                  stack.n++
                  stack.frames[stack.n - 1].calls = CALLS
                  stack.frames[stack.n - 1].callee = NO_FUN

                  goto recurse
return_from_recurse:
                  lib_handle_set = true
#else
                  lib_state = LOADED
                  lib_handle_set = true
#endif
                }
              fi

              // Publish shim address only in first call (this is imprecise but ok for now)

              atomic {
                if
                  :: rec_lock.count == 1 -> shim_table[stack.frames[stack.n - 1].callee - 1] = true
                  :: else -> skip
                fi
              }

              // Exit critical section

              assert(rec_lock.owner == tid && rec_lock.count > 0)

              atomic {
                rec_lock.count--
                if
                  :: rec_lock.count == 0 -> rec_lock.owner = NO_THREAD
                  :: else -> skip
                fi
              }
            }  // L.slow
          fi

          assert(lib_state == LOADING || lib_state == LOADED)

          // Function called
        }  // L.call
      fi
    }  // L.run
  od

  terminated++
}

init {
  int i

  // Init global state

  i = 1
  do
    :: i <= FUNS -> {
        shim_table[i - 1] = false
        i++
      }
    :: else -> break
  od

  lib_handle_set = false
  lib_state = UNLOADED
  rec_lock.owner = NO_THREAD
  rec_lock.count = 0

  terminated = 0

  // Start threads

  atomic {
    i = 1
    do
      :: i <= THREADS -> {
          run Thread(i)
          i++
        }
      :: else -> break
    od
  }

  // Termination(TLA): All threads terminate, lock is released and library is loaded

  terminated == THREADS

  assert(rec_lock.owner == NO_THREAD && rec_lock.count == 0)
  assert(lib_state == LOADED && lib_handle_set)
}

// Invariants

never {
  do
    // TypeInvariant(TLA)
    :: rec_lock.owner > THREADS -> break
    :: rec_lock.count > MAX_LOCK -> break

    // LockInvariant(TLA)
    :: rec_lock.owner == NO_THREAD ^ rec_lock.count == 0 -> break
    :: rec_lock.owner == NO_THREAD && lib_state == LOADING -> break

    // LibHandleCorrectness(TLA): Library handle set only if library is loaded (not necessarily initialized)
    :: lib_handle_set && lib_state != LOADING && lib_state != LOADED -> break

    :: else
  od
}

// NoLibResets(TLA): Library never UN-loaded
ltl NoLibResets {
  [](
    (lib_state == LOADING -> [](lib_state == LOADING || lib_state == LOADED))
    && (lib_state == LOADED -> [](lib_state == LOADED))
  )
}

// TODO: forall predicates (LoadBeforeUse2, NoShimResets)
