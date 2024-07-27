class CBQueue {
  constructor (timer) {
    this.timeout = timer || 1000;
    this.queue = [];
    this.id = null;
    this.running = true;
  }

  tick () {
    if (!this.running || !this.queue.length) {
      clearInterval(this.id);
      this.id = null;
      return;
    }
    this.queue.shift()();
  }

  add (cb) {
    this.queue.push(cb);
    if (this.running) {
      this.start();
    }
  }

  start () {
    let self = this;
    this.running = true;
    if (!this.id) {
      this.id = setInterval(function () {
        self.tick();
      }, this.timeout);
      this.tick();
    }
  }

  stop () {
    if (this.id) {
      clearInterval(this.id);
    }
    this.id = null;
    this.running = false;
  }
}

let SendQueue = new CBQueue(700);

export default CBQueue;
export { SendQueue };
