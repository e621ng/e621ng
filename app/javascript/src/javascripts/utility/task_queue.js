// Simple promise-based task queue.
// It allows us to schedule tasks in a way that prevents them from hitting the API rate limit.
// Tasks are executed sequentially, and each task must return a promise that resolves when the task is complete.
export default class TaskQueue {

  static _queue = [];
  static _running = false;

  /**
   * Adds a task to the queue.
   * @param {Function} task Task function to be executed. It may or may not be asynchronous.
   * @param {Object} options Configuration options for the task.
   * @param {number} options.delay Delay in milliseconds before the task is executed. Defaults to 1000, minimum 500.
   * @param {boolean} options.priority When true, adds the task to the front of the queue.
   * @param {string} options.name Optional name for the task. May not be unique.
   * @returns {Promise} Promise that resolves when the task is completed or rejects if the task fails.
   * @throws {Error} If the task is not a function or if the delay is not a non-negative number.
   */
  static add(task, options = {}) {
    if (typeof task !== "function") throw new Error("Task must be a function");
    
    let { delay = 1000, priority = false, name = null } = options;
    
    if (typeof delay !== "number" || delay < 0) throw new Error("Delay must be a non-negative number");
    if (delay < 500) delay = 500; // Minimum delay to prevent throttling server-side

    const result = new Promise((resolve, reject) => {
      const taskItem = { task, resolve, reject, delay, name };
      if (priority) this._queue.unshift(taskItem);
      else this._queue.push(taskItem);
    });
    this._run();
    return result;
  }

  /**
   * Runs the tasks in the queue.  
   * Should not be called directly; use `add` to enqueue tasks.
   * @returns {Promise<void>}
   */
  static async _run() {
    if (this._running || this._queue.length === 0) return;
    this._running = true;

    let currentDelay = 0;

    try {
      while (this._queue.length > 0 && this._running) {
        await this.sleep(currentDelay);
        
        // Abort if the task was cancelled or the queue was cleared
        if (!this._running || this._queue.length === 0) break;

        const { task, resolve, reject, delay, name } = this._queue.shift();
        currentDelay = delay;
        
        try {
          if (typeof task !== "function")
            throw new Error("Invalid task: not a function");
          
          const result = await task();
          resolve(result);
        } catch (error) {
          console.log("Task failed:", error);
          reject(error);
        }
      }
    } finally {
      this._running = false;
    }
  }

  /**
   * Returns a promise that resolves after a specified delay.
   * @param {number} ms Delay in milliseconds.
   * @returns {Promise<void>}
   */
  static sleep(ms = 1000) {
    if (typeof ms !== "number" || ms < 0)
      throw new Error("Sleep duration must be a non-negative number");
    if (ms === 0) return Promise.resolve();
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Clears the queue and rejects any running tasks with an error.
   * @param {string} reason Optional reason for clearing the queue.
   */
  static clear(reason = "Queue cleared") {
    this._running = false;
    this._queue.forEach(({ reject }) => {
      reject(new Error(reason));
    });
    this._queue = [];
  }

  /**
   * Cancels all tasks with the specified name.
   * @param {string} taskName The name of the tasks to cancel.
   * @param {string} reason Optional reason for cancelling the tasks.
   * @returns {number} The number of tasks that were cancelled.
   */
  static cancel(taskName, reason = "Task cancelled") {
    if (taskName === null || taskName === undefined) return 0;

    let count = 0;
    this._queue = this._queue.filter(({ name, reject }) => {
      if (name !== taskName) return true; // Keep in queue

      // Remove from queue
      reject(new Error(reason));
      count++;
      return false;
    });

    return count;
  }

  /** @returns {number} The length of the task queue. */
  static get length() {
    return this._queue.length;
  }

  /** @returns {boolean} True if the queue is running, false otherwise. */
  static get isRunning() {
    return this._running;
  }

  /**
   * Returns an array of pending tasks.
   * Each task is represented by an object containing its index, name, and delay.
   * @returns {Array} Array of pending tasks.
   */
  static get pending() {
    return this._queue.map(({ delay, name }, index) => ({
      index,
      name,
      delay,
    }));
  }
}
