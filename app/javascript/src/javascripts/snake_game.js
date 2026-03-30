/* eslint-disable */
// Point2d.ts
class Direction2d {
  x;
  y;
  static up = new Direction2d(0, -1);
  static down = new Direction2d(0, 1);
  static left = new Direction2d(-1, 0);
  static right = new Direction2d(1, 0);
  static directions = Object.freeze([this.up, this.down, this.left, this.right]);
  constructor(x, y) {
    this.x = x;
    this.y = y;
    Object.freeze(this);
  }
  get opposite() {
    return Direction2d.fromParameters(Point2d.scale(this, -1));
  }
  get asPoint() {
    return Point2d.fromIPoint2d(this);
  }
  static fromCardinalDisplacement(from, to) {
    const matchingAxis = Point2d.fromIPoint2d(from).matchingAxes(to);
    if (matchingAxis.length !== 1)
      return;
    if (matchingAxis[0] === 0 /* x */)
      return from.y > to.y ? this.up : this.down;
    return from.x > to.x ? this.left : this.right;
  }
  static fromParameters({ x, y }) {
    if (x === 0) {
      return y > 0 ? this.down : y !== 0 ? this.up : undefined;
    } else if (y === 0) {
      return x > 0 ? this.right : this.left;
    } else {
      return;
    }
  }
}

class Point2d {
  x;
  y;
  static terseToString = false;
  toString() {
    return `(${this.x}, ${this.y})`;
  }
  constructor(x, y) {
    this.x = x;
    this.y = y;
  }
  toIntPoint2d() {
    return { x: Math.floor(this.x), y: Math.floor(this.y) };
  }
  static toIntPoint2d(p) {
    return { x: Math.floor(p.x), y: Math.floor(p.y) };
  }
  toIPoint2d() {
    return { x: this.x, y: this.y };
  }
  static toIPoint2d(p) {
    return { x: p.x, y: p.y };
  }
  static fromIPoint2d(p) {
    return p instanceof Point2d ? p : new Point2d(p.x, p.y);
  }
  toIntObj = this.toIntPoint2d;
  static toIntObj = this.toIntPoint2d;
  toObj = this.toIPoint2d;
  static toObj = this.toIPoint2d;
  static fromObj = this.fromIPoint2d;
  getAxis(a) {
    return a === 0 /* x */ ? this.x : this.y;
  }
  static getAxis(p, a) {
    return a === 0 /* x */ ? p.x : p.y;
  }
  setAxis(a, value) {
    return a === 0 /* x */ ? this.x = value : this.y = value;
  }
  matchingAxes(v) {
    const r = [];
    if (this.x === v.x)
      r.push(0 /* x */);
    if (this.y === v.y)
      r.push(1 /* y */);
    return r;
  }
  static matchingAxes(p1, p2) {
    const r = [];
    if (p1.x === p2.x)
      r.push(0 /* x */);
    if (p1.y === p2.y)
      r.push(1 /* y */);
    return r;
  }
  isAxisAligned(other) {
    let r = false;
    if (this.x === other.x)
      r = !r;
    if (this.y === other.y)
      r = !r;
    return r;
  }
  static isAxisAligned(p1, p2) {
    let r = false;
    if (p1.x === p2.x)
      r = !r;
    if (p1.y === p2.y)
      r = !r;
    return r;
  }
  allAxisAligned(...others) {
    const axes = this.matchingAxes(others[0]);
    switch (axes.length) {
      case 0:
        return false;
      case 1:
        return others.every((e) => this.matchingAxes(e).includes(axes[0]));
      default:
        return axes.some((e1) => others.every((e) => this.matchingAxes(e).includes(e1)));
    }
  }
  static allAxisAligned(...points) {
    const axes = Point2d.matchingAxes(points[0], points[1]);
    switch (axes.length) {
      case 0:
        return false;
      case 1:
        return points.every((e) => Point2d.matchingAxes(points[0], e).includes(axes[0]));
      default:
        return axes.some((e1) => points.every((e) => Point2d.matchingAxes(points[0], e).includes(e1)));
    }
  }
  included(a) {
    return a.find((e) => this.equals(e)) ? true : false;
  }
  static included(p, a) {
    return a.find((e) => this.equals(p, e)) ? true : false;
  }
  static includes = this.included;
  indexIn(a, fromIndex) {
    return a.findIndex(fromIndex === undefined ? (e) => this.equals(e) : (e, i) => i >= fromIndex && this.equals(e));
  }
  static indexIn(p, a, fromIndex) {
    return a.findIndex(fromIndex === undefined ? (e) => this.equals(p, e) : (e, i) => i >= fromIndex && this.equals(p, e));
  }
  static subtract(p1, p2) {
    return new Point2d(p1.x - p2.x, p1.y - p2.y);
  }
  subtract({ x = 0, y = 0 }) {
    this.x -= x;
    this.y -= y;
    return this;
  }
  static add(p1, p2) {
    return new Point2d(p1.x + p2.x, p1.y + p2.y);
  }
  add({ x = 0, y = 0 }) {
    this.x += x;
    this.y += y;
    return this;
  }
  static equals(p1, p2) {
    return !!p1 && !!p2 && p1.x == p2.x && p1.y == p2.y;
  }
  equals(p) {
    return !!p && this.x == p.x && this.y == p.y;
  }
  static scale(p, v) {
    return new Point2d(p.x * v, p.y * v);
  }
  scale(v) {
    this.x *= v;
    this.y *= v;
    return this;
  }
  static abs(p) {
    return new Point2d(Math.abs(p.x), Math.abs(p.y));
  }
  abs() {
    this.x = Math.abs(this.x);
    this.y = Math.abs(this.y);
    return this;
  }
  static magnitude(p) {
    return Math.sqrt(p.x * p.x + p.y * p.y);
  }
  magnitude() {
    return Math.sqrt(this.x * this.x + this.y * this.y);
  }
  static hasMagnitudeOf(p1, magnitude, p2) {
    return !!p1 && !!p2 && Point2d.magnitude(Point2d.abs(Point2d.subtract(p1, p2))) == Math.abs(magnitude);
  }
  hasMagnitudeOf(magnitude, p) {
    return !!p && Point2d.magnitude(Point2d.abs(Point2d.subtract(this, p))) == Math.abs(magnitude);
  }
  static midpoint(p1, p2) {
    return new Point2d((p1.x + p2.x) / 2, (p1.y + p2.y) / 2);
  }
  intersects(p1, p2) {
    const m1 = this.matchingAxes(p1);
    switch (m1.length) {
      case 0:
        return false;
      case 2:
        return true;
      case 1:
        break;
      default:
        throw new Error(`Invalid value from Point2d.matchingAxes(${p1}) (${m1})`);
    }
    const m2 = this.matchingAxes(p2);
    switch (m2.length) {
      case 0:
        return false;
      case 2:
        return true;
      case 1:
        break;
      default:
        throw new Error(`Invalid value from Point2d.matchingAxes(${p2}) (${m2})`);
    }
    const a = m1.filter((e) => m2.includes(e));
    switch (a.length) {
      case 0:
        return false;
      case 1:
        break;
      default:
        throw new Error(`Invalid value from Point2d.intersects(${p2}) (${a})`);
    }
    if (a[0] === 1 /* y */) {
      return this.x <= p1.x && this.x >= p2.x || this.x <= p2.x && this.x >= p1.x;
    } else {
      return this.y <= p1.y && this.y >= p2.y || this.y <= p2.y && this.y >= p1.y;
    }
  }
}
class RectInt2d {
  _width;
  _height;
  get width() {
    return this._width;
  }
  set width(v) {
    this._width = Math.abs(v);
  }
  get height() {
    return this._height;
  }
  set height(v) {
    this._height = Math.abs(v);
  }
  get dimensions() {
    return { x: this.width, y: this.height };
  }
  set dimensions(v) {
    ({ x: this.width, y: this.height } = v);
  }
  min;
  get max() {
    return Point2d.add(this.min, Point2d.subtract(this.dimensions, { x: 1, y: 1 }));
  }
  get xExtent() {
    return this.width / 2;
  }
  set xExtent(v) {
    this.width = v * 2;
  }
  get yExtent() {
    return this.height / 2;
  }
  set yExtent(v) {
    this.height = v * 2;
  }
  get extents() {
    return { x: this.xExtent, y: this.yExtent };
  }
  set extents(v) {
    ({ x: this.xExtent, y: this.yExtent } = v);
  }
  get center() {
    return Point2d.add(this.min, this.extents);
  }
  get centerInt() {
    return Point2d.toIntPoint2d(this.center);
  }
  get xMin() {
    return this.min.x;
  }
  get xMax() {
    return this.max.x;
  }
  get yMin() {
    return this.min.y;
  }
  get yMax() {
    return this.max.y;
  }
  get leftEdge() {
    return [
      new Point2d(this.xMin, this.yMin),
      new Point2d(this.xMin, this.yMax)
    ];
  }
  get rightEdge() {
    return [
      new Point2d(this.xMax, this.yMin),
      new Point2d(this.xMax, this.yMax)
    ];
  }
  get topEdge() {
    return [
      new Point2d(this.xMin, this.yMin),
      new Point2d(this.xMax, this.yMin)
    ];
  }
  get bottomEdge() {
    return [
      new Point2d(this.xMin, this.yMax),
      new Point2d(this.xMax, this.yMax)
    ];
  }
  get edges() {
    return [this.leftEdge, this.rightEdge, this.topEdge, this.bottomEdge];
  }
  get leftBorderEdge() {
    return [
      new Point2d(this.xMin - 1, this.yMin - 1),
      new Point2d(this.xMin - 1, this.yMax + 1)
    ];
  }
  get rightBorderEdge() {
    return [
      new Point2d(this.xMax + 1, this.yMin - 1),
      new Point2d(this.xMax + 1, this.yMax + 1)
    ];
  }
  get topBorderEdge() {
    return [
      new Point2d(this.xMin - 1, this.yMin - 1),
      new Point2d(this.xMax + 1, this.yMin - 1)
    ];
  }
  get bottomBorderEdge() {
    return [
      new Point2d(this.xMin - 1, this.yMax + 1),
      new Point2d(this.xMax + 1, this.yMax + 1)
    ];
  }
  get borderEdges() {
    return [this.leftBorderEdge, this.rightBorderEdge, this.topBorderEdge, this.bottomBorderEdge];
  }
  get points() {
    const rv = [];
    for (let i = 0;i < this.width; i++)
      for (let j = 0;j < this.height; j++)
        rv.push({ x: i, y: j });
    return rv;
  }
  static fromMinMax(min, max) {
    if (min.x > max.x) {
      const t = min.x;
      min.x = max.x;
      max.x = t;
    }
    if (min.y > max.y) {
      const t = min.y;
      min.y = max.y;
      max.y = t;
    }
    const dimensions = Point2d.add(Point2d.subtract(max, min), { x: 1, y: 1 });
    return this.fromDimensionsAndMin(dimensions.x, dimensions.y, min);
  }
  static fromDimensionsAndCenter(width, height, point) {
    return new RectInt2d(width, height, point, true);
  }
  static fromDimensionsAndMin(width, height, point = { x: 0, y: 0 }) {
    return new RectInt2d(width, height, point);
  }
  constructor(_width, _height, point, isCenter = false) {
    this._width = _width;
    this._height = _height;
    if (_width < 0)
      this._width *= -1;
    if (_height < 0)
      this._height *= -1;
    this.min = isCenter ? Point2d.subtract(point, this.extents) : point;
  }
  intersects(p) {
    return this.xMin <= p.x && this.xMax >= p.x && this.yMin <= p.y && this.yMax >= p.y;
  }
  findIntersection(p) {
    for (const edge of this.edges) {
      if (p.intersects(edge[0], edge[1]))
        return edge;
    }
    return false;
  }
  findBorderIntersection(p) {
    for (const edge of this.borderEdges) {
      if (p.intersects(edge[0], edge[1]))
        return edge;
    }
    return false;
  }
  wrap(p) {
    while (p.x > this.xMax)
      p.x -= this.width;
    while (p.x < this.xMin)
      p.x += this.width;
    while (p.y > this.yMax)
      p.y -= this.height;
    while (p.y < this.yMin)
      p.y += this.height;
    return p;
  }
  unwrap(p, axis, operation) {
    if (axis === 0 /* x */) {
      if (operation === "decrement")
        p.x -= this.width;
      else if (operation === "increment")
        p.x += this.width;
    } else {
      if (operation === "decrement")
        p.y -= this.height;
      else if (operation === "increment")
        p.y += this.height;
    }
    return p;
  }
  unwrapRelative(p, reference) {
    const axis = Point2d.matchingAxes(p, reference)[0] === 0 /* x */ ? 1 /* y */ : 0 /* x */;
    const op = Point2d.getAxis(reference, axis) > Point2d.getAxis(p, axis) ? "increment" : "decrement";
    return this.unwrap(p, axis, op);
  }
  generatePointsWhere(predicate) {
    const rv = [];
    for (let i = 0;i < this.width; i++)
      for (let j = 0, e = { x: i, y: j };j < this.height; j++, e = { x: i, y: j })
        if (predicate(e, i * this.width + j))
          rv.push({ x: i, y: j });
    return rv;
  }
}

// DebugLevel.ts
class DebugLevel {
  index;
  _print;
  static NONE = new DebugLevel(0, () => {});
  static ERROR = new DebugLevel(1, console.error);
  static WARN = new DebugLevel(2, console.warn);
  static INFO = new DebugLevel(3, console.info);
  static LOG = new DebugLevel(4, console.log);
  static DEBUG = new DebugLevel(5, console.debug);
  constructor(index, _print) {
    this.index = index;
    this._print = _print;
  }
  static clone = false;
  static stringify = true;
  static parse = true;
  static handleParams(data) {
    if (this.clone)
      return data.map((e) => typeof e !== "object" ? e : structuredClone(e));
    if (!this.stringify)
      return data;
    return data.map((e) => {
      if (typeof e !== "object")
        return e;
      return this.parse ? JSON.parse(JSON.stringify(e)) : JSON.stringify(e);
    });
  }
  eval(level) {
    return this.index >= level.index && this.index !== 0;
  }
  print(level, ...data) {
    if (this.eval(level))
      level._print(...DebugLevel.handleParams(data));
  }
  do(level, cb, or) {
    return this.eval(level) ? cb(level._print) : or ? or(level._print) : undefined;
  }
  debugger(level = DebugLevel.DEBUG) {
    if (this.eval(level))
      debugger;
  }
  group(level, ...data) {
    if (this.eval(level))
      console.group(...DebugLevel.handleParams(data));
  }
  groupEnd(level) {
    if (this.eval(level))
      console.groupEnd();
  }
  static tableFromPointsAndPlayfield(points, playfield, asIndex = true) {
    const arr = [];
    for (let j = 0;j < playfield.height; j++) {
      const temp = [];
      for (let i = 0;i < playfield.width; i++) {
        if (asIndex) {
          temp.push(points.findIndex((e) => Point2d.equals(e, { x: i, y: j })));
          continue;
        }
        const v = points.find((e) => Point2d.equals(e, { x: i, y: j }));
        temp.push(v ? JSON.parse(JSON.stringify(v)) : v);
      }
      arr.push(temp);
    }
    console.table(arr);
  }
  static tableFromPointsAndDimensions(points, width, height, asIndex = true) {
    const arr = [];
    for (let j = 0;j < height; j++) {
      const temp = [];
      for (let i = 0;i < width; i++) {
        if (asIndex) {
          temp.push(points.findIndex((e) => Point2d.equals(e, { x: i, y: j })));
          continue;
        }
        const v = points.find((e) => Point2d.equals(e, { x: i, y: j }));
        temp.push(v ? JSON.parse(JSON.stringify(v)) : v);
      }
      arr.push(temp);
    }
    console.table(arr);
  }
}
var NONE = DebugLevel.NONE;
var ERROR = DebugLevel.ERROR;
var WARN = DebugLevel.WARN;
var INFO = DebugLevel.INFO;
var LOG = DebugLevel.LOG;
var DEBUG = DebugLevel.DEBUG;

// Events.ts
class SnakeEvent {
  listeners;
  onAdd;
  onRemove;
  constructor(listeners = [], onAdd, onRemove) {
    this.listeners = listeners;
    this.onAdd = onAdd;
    this.onRemove = onRemove;
  }
  fire(args) {
    this.listeners.forEach((f) => f(args));
  }
  add(...funcs) {
    for (const func of funcs) {
      this.listeners.push(func);
      if (this.onAdd)
        this.onAdd(func, this);
    }
  }
  remove(func) {
    const i = this.listeners.indexOf(func);
    if (i < 0)
      return false;
    const removed = this.listeners.splice(i, 1)[0];
    if (this.onRemove)
      this.onRemove(removed, this);
    return true;
  }
  removeEvery(func) {
    let count = 0;
    for (let i = this.listeners.indexOf(func);i >= 0; i = this.listeners.indexOf(func), count++) {
      const removed = this.listeners.splice(i, 1)[0];
      if (this.onRemove)
        this.onRemove(removed, this);
    }
    return count;
  }
  clear() {
    const cbs = this.listeners.splice(0);
    if (this.onRemove)
      cbs.forEach((e) => this.onRemove(e, this));
    return cbs;
  }
}

// InputHandler.ts
class InputAction {
  name;
  direction;
  static up = new InputAction("up", Direction2d.up);
  static down = new InputAction("down", Direction2d.down);
  static left = new InputAction("left", Direction2d.left);
  static right = new InputAction("right", Direction2d.right);
  static actions = [this.up, this.down, this.left, this.right];
  constructor(name, direction) {
    this.name = name;
    this.direction = direction;
  }
}

class InputDisplay {
  inputHandler;
  up;
  down;
  left;
  right;
  onInputUp;
  onInputDown;
  onKeyStateChange;
  constructor(inputHandler, up, down, left, right, onInputUp = this.defaultOnInputUp, onInputDown = this.defaultOnInputDown, onKeyStateChange = this.defaultOnKeyStateChange) {
    this.inputHandler = inputHandler;
    this.up = up;
    this.down = down;
    this.left = left;
    this.right = right;
    this.onInputUp = onInputUp;
    this.onInputDown = onInputDown;
    this.onKeyStateChange = onKeyStateChange;
    inputHandler.inputDown.add((e) => this.dispatchInputDown(e));
    inputHandler.inputUp.add((e) => this.dispatchInputUp(e));
    inputHandler.keyStateChanged.add((e) => this.onKeyStateChange(e));
    const t = { up: false, down: false, left: false, right: false };
    this.onKeyStateChange({ priorState: t, state: t });
  }
  static fromTouchInputHandler(inputHandler, onInputUp, onInputDown, onKeyStateChange) {
    return new InputDisplay(inputHandler, inputHandler.inputElements.up, inputHandler.inputElements.down, inputHandler.inputElements.left, inputHandler.inputElements.right, onInputUp, onInputDown, onKeyStateChange);
  }
  dispatchInputDown(args) {
    switch (args.action) {
      case InputAction.up:
        this.onInputDown(args, this.up);
        break;
      case InputAction.down:
        this.onInputDown(args, this.down);
        break;
      case InputAction.left:
        this.onInputDown(args, this.left);
        break;
      case InputAction.right:
        this.onInputDown(args, this.right);
        break;
    }
  }
  dispatchInputUp(args) {
    switch (args.action) {
      case InputAction.up:
        this.onInputUp(args, this.up, args.state.up);
        break;
      case InputAction.down:
        this.onInputUp(args, this.down, args.state.down);
        break;
      case InputAction.left:
        this.onInputUp(args, this.left, args.state.left);
        break;
      case InputAction.right:
        this.onInputUp(args, this.right, args.state.right);
        break;
    }
  }
  defaultOnInputDown(args, element, state = true) {
    element.style.backgroundColor = state ? "rgb(42, 82, 142, 1)" : "rgba(255, 0, 0, .5)";
  }
  defaultOnInputUp(args, element, state = false) {
    element.style.backgroundColor = "";
  }
  defaultOnKeyStateChange(args) {
    this.up.style.backgroundColor = args.state.up ? "rgb(42, 82, 142, 1)" : "";
    this.down.style.backgroundColor = args.state.down ? "rgb(42, 82, 142, 1)" : "";
    this.left.style.backgroundColor = args.state.left ? "rgb(42, 82, 142, 1)" : "";
    this.right.style.backgroundColor = args.state.right ? "rgb(42, 82, 142, 1)" : "";
  }
}

class InputHandler {
  watchedElement;
  currentStateOnly = false;
  static INPUT_QUEUE_LIMIT = 2;
  keyStateChanged = new SnakeEvent;
  inputDown = new SnakeEvent;
  inputUp = new SnakeEvent;
  _inputQueue = [];
  watchGlobal = true;
  constructor(watchedElement = undefined) {
    this.watchedElement = watchedElement;
    if (watchedElement && (!watchedElement.isContentEditable || typeof watchedElement.tabIndex !== "number" || watchedElement.tabIndex === -1))
      watchedElement.tabIndex = 0;
    this.initDefaultInputs();
  }
  setInputState(i, value = true) {
    const prior = structuredClone(this._keyState);
    this._keyState[i.name] = value;
    if (value)
      this.enqueueInputAction(i);
    this.keyStateChanged.fire({ action: i, state: structuredClone(this._keyState), priorState: prior });
  }
  enqueueInputAction(action) {
    if (!action)
      return false;
    const queue = this._inputQueue;
    const tail = queue.at(-1);
    if (tail?.direction === action.direction)
      return false;
    if (tail?.direction === action.direction.opposite)
      return false;
    if (queue.length >= InputHandler.INPUT_QUEUE_LIMIT)
      return false;
    queue.push(action);
    return true;
  }
  dequeueNextValidDirection(currentDirection) {
    while (this._inputQueue.length > 0) {
      const action = this._inputQueue.shift();
      if (!action)
        continue;
      if (currentDirection && action.direction === currentDirection.opposite)
        continue;
      return action.direction;
    }
    return undefined;
  }
  clearInputQueue() {
    this._inputQueue.splice(0);
  }
  isKeyDown(action) {
    return this._keyState[action.name];
  }
  wasKeyPressed = this.isKeyDown;
  getKeysDown() {
    const r = [];
    if (this._keyState.up)
      r.push(InputAction.up);
    if (this._keyState.down)
      r.push(InputAction.down);
    if (this._keyState.left)
      r.push(InputAction.left);
    if (this._keyState.right)
      r.push(InputAction.right);
    return r;
  }
  getKeysPressed = this.getKeysDown;
  _useDefaultInputSystem = true;
  get useDefaultInputSystem() {
    return this._useDefaultInputSystem;
  }
  set useDefaultInputSystem(v) {
    if (v === this._useDefaultInputSystem)
      return;
    this.toggleDefaultInputSystem();
  }
  toggleDefaultInputSystem() {
    this._useDefaultInputSystem = !this._useDefaultInputSystem;
    if (this._useDefaultInputSystem) {
      this.initDefaultInputs();
    } else {
      this.clearDefaultInputs();
    }
  }
  static defaultBindings = {
    up: ["ArrowUp", "Up", "w", "W"],
    down: ["ArrowDown", "Down", "s", "S"],
    left: ["ArrowLeft", "Left", "a", "A"],
    right: ["ArrowRight", "Right", "d", "D"]
  };
  static _defaultBindingsReversed;
  static get defaultBindingsReversed() {
    if (this._defaultBindingsReversed)
      return this._defaultBindingsReversed;
    this._defaultBindingsReversed = new Map;
    InputAction.actions.forEach((e) => this.defaultBindings[e.name].forEach((e1) => (this._defaultBindingsReversed?.get(e1) ?? this._defaultBindingsReversed?.set(e1, [])?.get(e1))?.push(e)));
    return this._defaultBindingsReversed;
  }
  _keyState = {
    up: false,
    down: false,
    left: false,
    right: false
  };
  get keyState() {
    return this._keyState;
  }
  onKeyShell(e, value) {
    if (e.target === this.watchedElement) {
      e.preventDefault();
      e.stopPropagation();
    } else if (!this.watchGlobal)
      return;
    if (value && e.repeat)
      return;
    const event = value ? this.inputDown : this.inputUp, prior = structuredClone(this._keyState), actions = InputHandler.defaultBindingsReversed.get(e.key);
    if (!this.currentStateOnly && !value) {
      const after2 = structuredClone(this._keyState);
      actions?.forEach((a2) => event.fire({ action: a2, state: after2, priorState: prior }));
      return;
    }
    let a;
    if (InputHandler.defaultBindings.up.includes(e.key)) {
      this._keyState.up = value;
      a = InputAction.up;
    } else if (InputHandler.defaultBindings.down.includes(e.key)) {
      this._keyState.down = value;
      a = InputAction.down;
    } else if (InputHandler.defaultBindings.left.includes(e.key)) {
      this._keyState.left = value;
      a = InputAction.left;
    } else if (InputHandler.defaultBindings.right.includes(e.key)) {
      this._keyState.right = value;
      a = InputAction.right;
    } else
      return;
    this.enqueueInputAction(a);
    const after = structuredClone(this._keyState);
    event.fire({ action: a, state: after, priorState: prior });
  }
  onKeyDownCb = (e) => this.onKeyShell(e, true);
  onKeyUpCb = (e) => this.onKeyShell(e, false);
  initDefaultInputs() {
    (this.watchedElement ?? document).addEventListener("keydown", this.onKeyDownCb);
    (this.watchedElement ?? document).addEventListener("keyup", this.onKeyUpCb);
  }
  clearDefaultInputs() {
    (this.watchedElement ?? document).removeEventListener("keydown", this.onKeyDownCb);
    (this.watchedElement ?? document).removeEventListener("keyup", this.onKeyUpCb);
  }
  resetState() {
    const prior = structuredClone(this._keyState);
    this._keyState = {
      up: false,
      down: false,
      left: false,
      right: false
    };
    this.keyStateChanged.fire({ state: structuredClone(this._keyState), priorState: prior });
  }
}

class TouchInputHandler extends InputHandler {
  inputElements;
  constructor(inputElements, watchedElement) {
    super(watchedElement);
    this.inputElements = inputElements;
    this.initDefaultTouchInputs();
  }
  _useDefaultTouchInputSystem = true;
  get useDefaultTouchInputSystem() {
    return this._useDefaultTouchInputSystem;
  }
  set useDefaultTouchInputSystem(v) {
    if (v === this._useDefaultTouchInputSystem)
      return;
    this.toggleDefaultTouchInputSystem();
  }
  toggleDefaultTouchInputSystem() {
    this._useDefaultTouchInputSystem = !this._useDefaultTouchInputSystem;
    if (this._useDefaultTouchInputSystem) {
      this.initDefaultTouchInputs();
    } else {
      this.clearDefaultTouchInputs();
    }
  }
  initDefaultTouchInputs() {
    this.inputElements.up.addEventListener("mousedown", this.cbMatrix.up.pressed);
    this.inputElements.up.addEventListener("mouseup", this.cbMatrix.up.released);
    this.inputElements.down.addEventListener("mousedown", this.cbMatrix.down.pressed);
    this.inputElements.down.addEventListener("mouseup", this.cbMatrix.down.released);
    this.inputElements.left.addEventListener("mousedown", this.cbMatrix.left.pressed);
    this.inputElements.left.addEventListener("mouseup", this.cbMatrix.left.released);
    this.inputElements.right.addEventListener("mousedown", this.cbMatrix.right.pressed);
    this.inputElements.right.addEventListener("mouseup", this.cbMatrix.right.released);
  }
  clearDefaultTouchInputs() {
    this.inputElements.up.removeEventListener("mousedown", this.cbMatrix.up.pressed);
    this.inputElements.up.removeEventListener("mouseup", this.cbMatrix.up.released);
    this.inputElements.down.removeEventListener("mousedown", this.cbMatrix.down.pressed);
    this.inputElements.down.removeEventListener("mouseup", this.cbMatrix.down.released);
    this.inputElements.left.removeEventListener("mousedown", this.cbMatrix.left.pressed);
    this.inputElements.left.removeEventListener("mouseup", this.cbMatrix.left.released);
    this.inputElements.right.removeEventListener("mousedown", this.cbMatrix.right.pressed);
    this.inputElements.right.removeEventListener("mouseup", this.cbMatrix.right.released);
  }
  cbMatrix = {
    up: {
      pressed: (_e) => this.setInputState(InputAction.up, true),
      released: (_e) => this.setInputState(InputAction.up, false)
    },
    down: {
      pressed: (_e) => this.setInputState(InputAction.down, true),
      released: (_e) => this.setInputState(InputAction.down, false)
    },
    left: {
      pressed: (_e) => this.setInputState(InputAction.left, true),
      released: (_e) => this.setInputState(InputAction.left, false)
    },
    right: {
      pressed: (_e) => this.setInputState(InputAction.right, true),
      released: (_e) => this.setInputState(InputAction.right, false)
    }
  };
}

// HtmlTemplate.ts
function template(render, wrapper) {
  return function(strings, ...args) {
    const parts = [];
    let string = strings[0] || "", part, root = null, node, nodes, walker, i, n, j, m, k = -1;
    args.unshift(strings);
    for (i = 1, n = args.length;i < n; ++i) {
      part = args[i];
      if (part instanceof Node) {
        parts[++k] = part;
        string += "<!--o:" + k + "-->";
      } else if (Array.isArray(part)) {
        for (j = 0, m = part.length;j < m; ++j) {
          node = part[j];
          if (node instanceof Node) {
            if (root === null) {
              parts[++k] = root = document.createDocumentFragment();
              string += "<!--o:" + k + "-->";
            }
            root.appendChild(node);
          } else {
            root = null;
            string += node;
          }
        }
        root = null;
      } else {
        string += part;
      }
      string += strings[i];
    }
    root = render(string);
    if (++k > 0) {
      nodes = new Array(k);
      walker = document.createTreeWalker(root, NodeFilter.SHOW_COMMENT, null);
      while (walker.nextNode()) {
        node = walker.currentNode;
        if (/^o:/.test(node.nodeValue || "")) {
          nodes[+node.nodeValue.slice(2)] = node;
        }
      }
      for (i = 0, node = nodes[i];i < k; node = nodes[++i]) {
        node?.parentNode?.replaceChild(parts[i], node);
      }
    }
    return root.childNodes.length === 1 ? root.removeChild(root.firstChild) : root.nodeType === Node.DOCUMENT_FRAGMENT_NODE ? ((node = wrapper()).appendChild(root), node) : root;
  };
}
var html = template(function(string) {
  const template2 = document.createElement("template");
  template2.innerHTML = string.trim();
  return document.importNode(template2.content, true);
}, function() {
  return document.createElement("span");
});

// Types.ts
class EngineConfig {
  gridWidth;
  gridHeight;
  pelletConfig;
  obstacleConfig;
  millisecondsPerUpdate;
  wallBehavior;
  startingLength;
  startingDirection;
  startingNodes;
  constructor(gridWidth, gridHeight, pelletConfig, obstacleConfig, millisecondsPerUpdate, wallBehavior, startingLength, startingDirection, startingNodes) {
    this.gridWidth = gridWidth;
    this.gridHeight = gridHeight;
    this.pelletConfig = pelletConfig;
    this.obstacleConfig = obstacleConfig;
    this.millisecondsPerUpdate = millisecondsPerUpdate;
    this.wallBehavior = wallBehavior;
    this.startingLength = startingLength;
    this.startingDirection = startingDirection;
    this.startingNodes = startingNodes;
  }
  static fromObj(i) {
    return new EngineConfig(i.gridWidth, i.gridHeight, i.pelletConfig, i.obstacleConfig, i.millisecondsPerUpdate, i.wallBehavior, i.startingLength, i.startingDirection, i.startingNodes);
  }
  static get defaults() {
    return {
      gridWidth: 10,
      gridHeight: 10,
      startingDirection: Direction2d.up,
      startingLength: 5,
      wallBehavior: 0 /* endGame */,
      pelletConfig: { startingObjs: 1, maxObjs: 1 },
      obstacleConfig: { startingObjs: 0, maxObjs: 0 },
      millisecondsPerUpdate: 1000 * 0.45,
      startingNodes: undefined
    };
  }
  static defaultConfig = Object.freeze(this.defaults);
  static isValidConfig(c) {
    return this.hasValidDimensions(c) && (c.startingLength || 0) > 2 && c.startingLength < NodeGeneration.MAX_GENERATED_LENGTH && this.hasValidObstacleConfig(c) && this.hasValidPelletConfig(c) && c.startingLength + c.pelletConfig.maxObjs + c.obstacleConfig.maxObjs <= c.gridWidth * c.gridHeight && c.millisecondsPerUpdate > 0 && (!c.startingNodes || c.startingNodes.length === c.startingLength && (!c.startingDirection || c.startingDirection === Direction2d.fromCardinalDisplacement(c.startingNodes[1], c.startingNodes[0])));
  }
  static hasValidDimensions(c) {
    return Number.isSafeInteger(c.gridWidth) && Number.isSafeInteger(c.gridHeight) && c.gridWidth > 2 && c.gridHeight > 2;
  }
  static hasValidIGridObjectConfig(c, minObjs, maxFreeSpaces) {
    return c.maxObjs >= minObjs && c.maxObjs >= (c.startingObjs instanceof Array ? c.startingObjs.length : c.startingObjs) && (c.startingObjs instanceof Array ? c.startingObjs.length : c.startingObjs) >= 0 && (!maxFreeSpaces || c.maxObjs < maxFreeSpaces);
  }
  static hasValidPelletConfig(c) {
    return this.hasValidIGridObjectConfig(c.pelletConfig, 1, c.gridWidth * c.gridHeight - c.startingLength);
  }
  static hasValidObstacleConfig(c) {
    return this.hasValidIGridObjectConfig(c.obstacleConfig, 0, c.gridWidth * c.gridHeight - c.startingLength);
  }
  static hasValidSnakeConfig(c) {
    return (c.startingLength || 0) > 2 && c.startingLength < NodeGeneration.MAX_GENERATED_LENGTH;
  }
  static inputType(element) {
    if (element instanceof HTMLInputElement) {
      switch (element.type) {
        case "number":
        case "range":
          return "number";
        case "text":
        case "url":
          return "string";
        case "radio":
          return "enum";
        default:
          return "undefined";
      }
    }
    if (element instanceof HTMLTextAreaElement)
      return "string";
    return "undefined";
  }
  static inputTypeSpecific(element) {
    const v = this.inputType(element);
    if (v !== "enum")
      return v;
    return element.dataset["enum"];
  }
  static fromFormAndData(form, data, defaults = this.defaultConfig) {
    const rv = {};
    data.forEach((value, key) => {
      let actingObj = rv, actingKey = key;
      if (key.includes(".")) {
        const keys = key.split(".");
        for (let i = 0;i < keys.length - 1; actingObj = actingObj[keys[i++]]) {
          actingObj[keys[i]] ||= {};
        }
        actingKey = keys.at(-1);
      }
      let parsedValue;
      const element = form.querySelector(`[name=${CSS.escape(key)}]${form.querySelector(`input[name=${CSS.escape(key)}][type=radio]`) ? `[value=${CSS.escape(value.toString())}]` : ""}`), iType = this.inputType(element);
      switch (iType) {
        case "number":
          parsedValue = Number(value);
          break;
        case "enum":
          switch (this.inputTypeSpecific(element)) {
            case "WallBehavior":
              parsedValue = value.toString().includes("wrap") || value.valueOf() == 1 /* wrap */.valueOf() ? 1 /* wrap */ : 0 /* endGame */;
              break;
            case "string":
            default:
              parsedValue = value;
              break;
          }
          break;
        case "string":
        default:
          parsedValue = value;
          break;
      }
      actingObj[actingKey] = parsedValue;
    });
    return Object.assign({}, defaults, rv);
  }
  static fromFormDataEvent(e, defaults = this.defaultConfig) {
    if (!(e.target instanceof HTMLFormElement)) {
      console.warn("`FormDataEvent.target` is not an instance of `HTMLFormElement`");
      return this.defaultConfig;
    }
    return this.fromFormAndData(e.target, e.formData, defaults);
  }
  static fromSubmitEvent(e, defaults = this.defaultConfig) {
    if (!(e.target instanceof HTMLFormElement)) {
      console.warn("`FormDataEvent.target` is not an instance of `HTMLFormElement`");
      return this.defaultConfig;
    }
    return this.fromFormAndData(e.target, new FormData(e.target, e.submitter), defaults);
  }
  static refreshOnResolution(obj, onParsed) {
    const cb = (v) => {
      obj.defaults = v;
      obj.promise = this.createPromise(obj.form, obj.defaults, cb, onParsed);
    };
    obj.promise = this.createPromise(obj.form, obj.defaults, cb, onParsed);
    return obj;
  }
  static createPromise(form, defaults, preResolution, postResolution) {
    return new Promise((resolve, _reject) => {
      const listener = (e) => {
        e.preventDefault();
        e.stopImmediatePropagation();
        const newCfg = this.fromSubmitEvent(e, defaults);
        preResolution?.call(this, newCfg);
        resolve(newCfg);
        postResolution?.call(this, newCfg);
        form.removeEventListener("submit", listener);
      };
      form.addEventListener("submit", listener);
    });
  }
  static toUI(c, onParsed) {
    const elem = html`
    <form id="snake-settings" style="display: inline-flex; flex-direction: column;">
      <label>Starting Length: <input type=number value=${c.startingLength} name="startingLength" min=2 step=1 /></label>
      <label>Grid Width: <input type=number value=${c.gridWidth} name="gridWidth" /></label>
      <label>Grid Height: <input type=number value=${c.gridHeight} name="gridHeight" /></label>
      <label>Tick rate: <input type=number value=${c.millisecondsPerUpdate} name="millisecondsPerUpdate" /> milliseconds per update</label>
      <fieldset>
        <legend>Going off-screen:</legend>
        <label><input type=radio value=${0 /* endGame */}${c.wallBehavior === 0 /* endGame */ ? " checked" : ""} name=wallBehavior data-enum=WallBehavior /> is a game over</label>
        <label><input type=radio value=${1 /* wrap */}${c.wallBehavior === 1 /* wrap */ ? " checked" : ""} name=wallBehavior data-enum=WallBehavior /> wraps around to the other side</label>
      </fieldset>
      <fieldset>
        <legend>Pellets</legend>
        <label>Starting: <input type=number value=${c.pelletConfig.startingObjs} name=pelletConfig.startingObjs /></label>
        <label>Max: <input type=number value=${c.pelletConfig.maxObjs} name=pelletConfig.maxObjs /></label>
      </fieldset>
      <fieldset>
        <legend>Obstacles</legend>
        <label>Starting: <input type=number value=${c.obstacleConfig.startingObjs} name=obstacleConfig.startingObjs /></label>
        <label>Max: <input type=number value=${c.obstacleConfig.maxObjs} name=obstacleConfig.maxObjs /></label>
      </fieldset>
      <input type="submit" value="Start a new game with chosen settings" />
    </form>
    `;
    return this.refreshOnResolution({ form: elem, defaults: c }, onParsed);
  }
}
function randomIndex(a) {
  return Math.floor(a.length * Math.random());
}
class NodeGeneration {
  static DEBUG_LEVEL = DebugLevel.INFO;
  static findValidNeighborIndices(node, validNodes) {
    return Direction2d.directions.reduce((accumulator, direction) => {
      const neighbor = Point2d.add(node, direction), t = validNodes.findIndex((e) => neighbor.equals(e));
      if (t !== -1)
        accumulator.push(t);
      return accumulator;
    }, []);
  }
  static generateFacingDirection(validNodes, desiredLength, direction) {
    const newDesiredLength = desiredLength;
    const starts = validNodes.reduce((acc, potentialHead, i) => {
      const secondNodeIndex = validNodes.findIndex((e) => Point2d.equals(Point2d.subtract(potentialHead, direction), e));
      if (secondNodeIndex >= 0) {
        const [i1, i2] = i < secondNodeIndex ? [i, secondNodeIndex] : [secondNodeIndex, i];
        acc.push({
          nodes: [Point2d.fromIPoint2d(potentialHead), Point2d.fromIPoint2d(validNodes[secondNodeIndex])],
          validNodes: validNodes.slice(0, i1).concat(validNodes.slice(i1 + 1, i2), validNodes.slice(i2 + 1))
        });
      }
      return acc;
    }, []);
    let rv, best;
    do {
      const args = starts.splice(randomIndex(starts), 1)[0];
      rv = this.depthFirst(args.nodes, args.validNodes, newDesiredLength);
      if (!best || rv.success || rv.nodes.length > best.nodes.length)
        best = rv;
    } while (!rv.success && starts.length > 0);
    return rv;
  }
  static generateFromValidNodes(desiredLength, validNodes, startingDirection) {
    if (startingDirection)
      return this.generateFacingDirection(validNodes, desiredLength, startingDirection);
    else
      return this.depthFirst([], validNodes, desiredLength);
  }
  static generateFromPlayfield(desiredLength, playfield, claimedNodes, startingDirection) {
    this.depthFirst_playfield = playfield;
    const rv = this.generateFromValidNodes(desiredLength, this.getInitialValidNodes(playfield, claimedNodes), startingDirection);
    this.depthFirst_playfield = undefined;
    return rv;
  }
  static generateFromSnakeConfig(config, playfield, claimedNodes) {
    return this.generateFromPlayfield(config.startingLength, playfield, claimedNodes, config.startingDirection);
  }
  static generateFromEngineConfig(config) {
    const claimedNodes = [];
    if (typeof config.obstacleConfig.startingObjs === "object")
      claimedNodes.push(...config.obstacleConfig.startingObjs);
    if (typeof config.pelletConfig.startingObjs === "object")
      claimedNodes.push(...config.pelletConfig.startingObjs);
    return this.generateFromSnakeConfig(config, RectInt2d.fromDimensionsAndMin(config.gridWidth, config.gridHeight), claimedNodes);
  }
  static MAX_GENERATED_LENGTH = 75;
  static depthFirst_iterations = 0;
  static depthFirst_maxLength = 0;
  static depthFirst_playfield;
  static depthFirst_iterationLimit = 1e5;
  static depthFirst_depth = 0;
  static depthFirst(nodes, validNodes, desiredLength) {
    this.depthFirst_depth++;
    this.depthFirst_iterations++;
    this.DEBUG_LEVEL.do(LOG, (print) => {
      let css = "";
      if (nodes.length > this.depthFirst_maxLength) {
        this.depthFirst_maxLength = nodes.length;
        css = "color: green; text-decoration: underline;";
      }
      print(`depthFirst(%s nodes, %s validNodes, desiredLength: %s)
	iterations: %s
%c	max: %s`, nodes.length, validNodes.length, desiredLength, this.depthFirst_iterations, css, this.depthFirst_maxLength);
    });
    if (nodes.length === desiredLength) {
      this.DEBUG_LEVEL.do(INFO, (print) => {
        print("SUCCESS at %s iterations", this.depthFirst_iterations);
        this.depthFirst_iterations = this.depthFirst_maxLength = 0;
      });
      this.depthFirst_depth--;
      return { success: true, nodes, validNodes };
    }
    if (this.depthFirst_iterations >= this.depthFirst_iterationLimit) {
      this.DEBUG_LEVEL.do(WARN, (print) => {
        print("FAILURE: Exceeded cap of %s iterations (%s)", this.depthFirst_iterationLimit, this.depthFirst_iterations);
        this.depthFirst_maxLength = 0;
      });
      this.DEBUG_LEVEL.debugger(DEBUG);
      this.depthFirst_depth--;
      return { success: false, nodes, validNodes };
    }
    const options = nodes.length < 1 ? Array.from(validNodes.keys()) : this.findValidNeighborIndices(nodes.at(-1), validNodes);
    if (options.length < 1) {
      this.DEBUG_LEVEL.do(INFO, (print) => {
        print("FAILED: No options");
        if (this.depthFirst_playfield)
          DebugLevel.tableFromPointsAndPlayfield(nodes, this.depthFirst_playfield);
      });
      this.depthFirst_depth--;
      return { success: false, nodes, validNodes };
    }
    this.DEBUG_LEVEL.print(DEBUG, "%s options", options.length);
    do {
      const nodeIndex = options.splice(randomIndex(options), 1)[0], node = validNodes[nodeIndex], vnCopy = validNodes.slice(0, nodeIndex).concat(validNodes.slice(nodeIndex + 1)), result = this.depthFirst(nodes.concat([Point2d.fromIPoint2d(node)]), vnCopy, desiredLength);
      if (result.success) {
        this.depthFirst_depth--;
        return result;
      }
    } while (options.length > 0 && this.depthFirst_iterations < this.depthFirst_iterationLimit);
    this.DEBUG_LEVEL.print(DEBUG, "FAILED: All options failed");
    if (--this.depthFirst_depth === 0)
      this.depthFirst_iterations = 0;
    return { success: false, nodes, validNodes };
  }
  static ALLOW_STARTING_NODES_ON_PERIMETER = true;
  static isOnPerimeter(e, playfield) {
    return e.x > playfield.xMin && e.x < playfield.xMax - 1 && e.y > playfield.yMin && e.y < playfield.yMax - 1;
  }
  static getInitialValidNodes(playfield, claimedNodes) {
    if (this.ALLOW_STARTING_NODES_ON_PERIMETER) {
      if (claimedNodes) {
        return playfield.generatePointsWhere((e) => !Point2d.included(e, claimedNodes));
      } else {
        return playfield.points;
      }
    } else {
      return playfield.generatePointsWhere(claimedNodes ? (e) => this.isOnPerimeter(e, playfield) && !Point2d.included(e, claimedNodes) : (e) => this.isOnPerimeter(e, playfield));
    }
  }
  static removeSurplusNodes(nodes) {
    for (let i = 1;i < nodes.length - 1; i++) {
      if (nodes[i + 1].matchingAxes(nodes[i])[0] == nodes[i].matchingAxes(nodes[i - 1])[0]) {
        this.DEBUG_LEVEL.print(LOG, "Removing redundant segment");
        nodes.splice(i, 1);
      }
    }
    return nodes;
  }
}

// Snake.ts
class Snake {
  config;
  playfield;
  static DEBUG_LEVEL = DebugLevel.INFO;
  _snakeLength;
  get snakeLength() {
    return Snake.STORES_SEGMENTS_ONLY ? this._snakeLength : this._snakeNodes.length;
  }
  constructor(config, startingNodes, playfield) {
    this.config = config;
    this.playfield = playfield;
    this._lastDirection = Direction2d.fromCardinalDisplacement(startingNodes[1], startingNodes[0]);
    this._snakeLength = this.config.startingLength;
    this._snakeNodes = startingNodes.slice();
  }
  static fromPreferences(config, playfield, claimedNodes) {
    if (config.startingNodes)
      return new Snake(config, config.startingNodes, playfield);
    if (!config.startingLength || config.startingLength > NodeGeneration.MAX_GENERATED_LENGTH || config.startingLength < 2)
      throw new Error("Invalid Config");
    let rv = { success: false, nodes: [], validNodes: [] };
    for (let i = 0;!rv.success && i < 20; i++)
      rv = NodeGeneration.generateFromSnakeConfig(config, playfield, claimedNodes);
    if (!rv.success)
      throw new Error(`Only Generated ${rv.nodes.length} of ${config.startingLength}`);
    return new Snake(config, Snake.STORES_SEGMENTS_ONLY ? NodeGeneration.removeSurplusNodes(rv.nodes) : rv.nodes, playfield);
  }
  _lastDirection;
  get lastDirection() {
    return this._lastDirection;
  }
  _snakeNodes = [];
  get head() {
    return this._snakeNodes[0];
  }
  get tail() {
    return this._snakeNodes.at(-1);
  }
  get snakeNodesDebug() {
    return this._snakeNodes.slice();
  }
  get filledNodes() {
    if (!Snake.STORES_SEGMENTS_ONLY)
      return this._snakeNodes.slice();
    const rv = this.segmentPoints.reduce((acc, c) => {
      const p = acc.at(-1);
      if (p.equals(c))
        return acc;
      const deltaAxis = p.x === c.x ? p.y === c.y ? undefined : 1 /* y */ : 0 /* x */;
      if (deltaAxis === undefined)
        return acc;
      const [pDeltaAxis, cDeltaAxis] = [p.getAxis(deltaAxis), c.getAxis(deltaAxis)];
      for (let i = pDeltaAxis;cDeltaAxis > pDeltaAxis ? ++i <= cDeltaAxis : --i >= cDeltaAxis; ) {
        const newPoint = new Point2d(c.x, c.y);
        newPoint.setAxis(deltaAxis, i);
        if (!p.equals(newPoint))
          acc.push(newPoint);
      }
      return acc;
    }, [this._snakeNodes[0]]);
    if (rv.length !== this.snakeLength) {
      Snake.DEBUG_LEVEL.group(INFO, "Snake.filledNodes: Failed to add all points");
      Snake.DEBUG_LEVEL.print(DEBUG, `	Snake Nodes: %o
	Generated Nodes: %o`, this._snakeNodes, rv);
      Snake.DEBUG_LEVEL.groupEnd(INFO);
      Snake.DEBUG_LEVEL.debugger(DEBUG);
    }
    return rv;
  }
  get segmentPoints() {
    if (Snake.STORES_SEGMENTS_ONLY)
      return this._snakeNodes.slice();
    return this._snakeNodes.reduce((acc, e) => {
      if (acc.length > 1 && Point2d.allAxisAligned(...acc.slice(-2), e)) {
        acc.pop();
      }
      acc.push(e);
      return acc;
    }, []);
  }
  get segments() {
    if (!Snake.STORES_SEGMENTS_ONLY) {
      return this._snakeNodes.reduce((acc, e) => {
        if (acc.length <= 0) {
          acc = [[e]];
        } else if (acc.at(-1).length < 2 || Point2d.allAxisAligned(...acc.at(-1), e)) {
          acc.at(-1)[1] = e;
        } else {
          acc.push([acc.at(-1).at(-1), e]);
        }
        return acc;
      }, []);
    }
    const t = this._snakeNodes.reduce((acc, e) => {
      if (acc[0])
        acc.at(-1).push(e);
      acc.push([e]);
      return acc;
    }, []);
    t.pop();
    return t;
  }
  get headSegment() {
    if (this.segmentPoints.length < 2) {
      Snake.DEBUG_LEVEL.print(WARN, "Can't get head segment; less than 2 nodes.");
      Snake.DEBUG_LEVEL.print(DEBUG, "\tNodes: %o", this.segmentPoints);
      return;
    }
    return this.segmentPoints.slice(0, 2);
  }
  get tailSegment() {
    if (this.segmentPoints.length < 2) {
      Snake.DEBUG_LEVEL.print(WARN, "Can't get tail segment; less than 2 nodes.");
      Snake.DEBUG_LEVEL.print(DEBUG, "\tNodes: %o", this.segmentPoints);
      return;
    }
    return this.segmentPoints.slice(-2);
  }
  get facingDirections() {
    return this.segments.map((e, i) => Snake.directionFromPoints(e, `#${i}`, this.config, this.playfield));
  }
  static isWrappedSegment(s, config) {
    if (config?.wallBehavior === 1 /* wrap */ && !Snake.STORES_SEGMENTS_ONLY && (s?.at(0) && s?.at(1) && !s[0].hasMagnitudeOf(1, s[1]))) {
      return true;
    }
    return false;
  }
  static directionFromPoints(s, label, config, playfield) {
    if (this.isWrappedSegment(s, config)) {
      Snake.DEBUG_LEVEL.print(DebugLevel.INFO, "%o is Wrapped Segment", s);
      if (!playfield)
        throw new Error("Can't resolve w/o playfield");
      s[1] = playfield.unwrapRelative(new Point2d(s[1].x, s[1].y), s[0]);
      Snake.DEBUG_LEVEL.print(DebugLevel.LOG, "\tResolved to: %o", s[1]);
    }
    const d = s ? Direction2d.fromCardinalDisplacement(s[1], s[0]) : undefined;
    if (!d) {
      Snake.DEBUG_LEVEL.print(WARN, "Can't get %s direction; can't get %s %s", label.toLowerCase(), label.toLowerCase(), s ? "direction" : "segment");
      Snake.DEBUG_LEVEL.print(DEBUG, "\t%s segment: %o", label, s);
      Snake.DEBUG_LEVEL.debugger(DEBUG);
    }
    return d;
  }
  get headDirection() {
    return Snake.directionFromPoints(this._snakeNodes.slice(0, 2), "Head", this.config, this.playfield);
  }
  get tailDirection() {
    return Snake.directionFromPoints(this.tailSegment, "Tail", this.config, this.playfield);
  }
  advance(d, grow = false, playfield = this.playfield) {
    Snake.DEBUG_LEVEL.group(LOG, "Snake.advance(%o, %o, %o)", d, grow, playfield);
    Snake.DEBUG_LEVEL.print(LOG, "Initial nodes (%s): %o", this._snakeNodes.length, this._snakeNodes);
    const backedUpState = this._snakeNodes.slice();
    if (!grow) {
      Snake.DEBUG_LEVEL.print(DEBUG, "Not growing; handling tail advancement");
      if (Point2d.subtract(this.tail, this._snakeNodes.at(-2)).magnitude() === 1 || !Snake.STORES_SEGMENTS_ONLY) {
        Snake.DEBUG_LEVEL.print(DEBUG, "needs to move tail");
        if (this.segmentPoints.length == 2)
          Snake.DEBUG_LEVEL.debugger(DEBUG);
        const oldTail = this._snakeNodes.pop();
        Snake.DEBUG_LEVEL.print(DEBUG, `Removed tail node
Old: %o
New: %o`, oldTail, this.tail);
      } else {
        if (!this.tailDirection)
          Snake.DEBUG_LEVEL.debugger(DEBUG);
        Snake.DEBUG_LEVEL.print(DEBUG, "Sliding tail node (%o) towards %o", this.tail, this.tailDirection);
        this.tail.add(this.tailDirection);
        Snake.DEBUG_LEVEL.print(DEBUG, "New tail position: %o", this.tail);
      }
    } else {
      this._snakeLength++;
    }
    let addedExtraTurn = false;
    if (d !== this.lastDirection) {
      if (Snake.STORES_SEGMENTS_ONLY) {
        this._snakeNodes.unshift(new Point2d(this.head.x, this.head.y));
        addedExtraTurn = true;
      }
      this._lastDirection = d;
    }
    const rv = this.updateHead(d, playfield, addedExtraTurn);
    if (rv) {
      this._snakeNodes.splice(0, this._snakeNodes.length, ...backedUpState);
      if (grow)
        this._snakeLength--;
    }
    Snake.DEBUG_LEVEL.groupEnd(LOG);
    return rv;
  }
  static STORES_SEGMENTS_ONLY = false;
  updateHead(d, playfield, ignoreFirstSeg = false) {
    Snake.DEBUG_LEVEL.group(INFO, "Snake.updateHead(%o, %o, %o)", d, playfield, ignoreFirstSeg);
    const projectedPosition = Point2d.add(this.head, d);
    Snake.DEBUG_LEVEL.print(INFO, `Current Position: %o
Projected Position: %o
Direction: %o`, this.head, projectedPosition, d);
    let intersection = false;
    switch (this.config.wallBehavior) {
      case 1 /* wrap */:
        Snake.DEBUG_LEVEL.print(INFO, "Do wrap");
        if ((playfield || this.playfield).findBorderIntersection(projectedPosition)) {
          const n = (playfield || this.playfield).wrap(projectedPosition);
          projectedPosition.x = n.x;
          projectedPosition.y = n.y;
        }
        break;
      case 0 /* endGame */:
        intersection = (playfield || this.playfield).findBorderIntersection(projectedPosition);
        if (intersection)
          Snake.DEBUG_LEVEL.print(WARN, "Collided with wall");
        break;
    }
    const checkSelfIntersection = Snake.STORES_SEGMENTS_ONLY ? () => {
      return (!ignoreFirstSeg ? this.segments : this.segments.slice(1)).find((e) => projectedPosition.intersects(e[0], e[1]));
    } : () => {
      const i = projectedPosition.indexIn(this.filledNodes);
      if (i >= 0) {
        return (!ignoreFirstSeg ? this.segments : this.segments.slice(1)).find((e) => projectedPosition.intersects(e[0], e[1]));
      }
    };
    const assignNewHead = Snake.STORES_SEGMENTS_ONLY ? () => {
      this.head.x = projectedPosition.x;
      this.head.y = projectedPosition.y;
    } : () => this._snakeNodes.unshift(projectedPosition);
    intersection ||= checkSelfIntersection();
    if (intersection) {
      Snake.DEBUG_LEVEL.print(WARN, "Collided on segment %o", intersection);
      Snake.DEBUG_LEVEL.groupEnd(INFO);
      return intersection;
    }
    assignNewHead();
    Snake.DEBUG_LEVEL.groupEnd(INFO);
  }
  findProjectedHeadPosition(d, playfield) {
    let projectedPosition = Point2d.add(this.head, d);
    if (this.config.wallBehavior === 1 /* wrap */) {
      projectedPosition = (playfield || this.playfield).wrap(projectedPosition);
    }
    return projectedPosition;
  }
}
var Snake_default = Snake;

// EngineDriver.ts
class EngineDriver {
  engine;
  get onManualUpdateMode() {
    return SnakeEngine.debugLevel.eval(DebugLevel.DEBUG);
  }
  timerId;
  _isDriving = true;
  get isDriving() {
    return this._isDriving;
  }
  constructor(engine) {
    this.engine = engine;
  }
  startDriving() {
    if (this.isDriving && this.timerId)
      return false;
    this._isDriving = true;
    if (this.onManualUpdateMode)
      document.onkeyup = this.bound_playOnSpaceBar;
    else
      this.timerId = window.setInterval(() => this.engine.update(), this.engine.config.millisecondsPerUpdate);
    return true;
  }
  playOnSpaceBar(e) {
    if (e.key === " ")
      this.engine.update();
  }
  bound_playOnSpaceBar = this.playOnSpaceBar.bind(this);
  stopDriving(force = false) {
    if (!force && !this.timerId && document.onkeyup !== this.playOnSpaceBar && document.onkeyup !== this.bound_playOnSpaceBar)
      return false;
    if (!this.onManualUpdateMode) {
      window.clearInterval(this.timerId);
      this.timerId = undefined;
    } else {
      document.onkeyup = null;
    }
    this._isDriving = false;
    return true;
  }
}

// UiStat.ts
function _shellMappedElements(gen, initial) {
  return (v) => {
    const newEs = gen(v);
    for (const key in initial) {
      if (!Object.hasOwn(initial, key))
        continue;
      const oldE = initial[key], newE = newEs[key];
      if (!oldE || !newE)
        continue;
      oldE.parentElement?.replaceChild(newE, oldE);
    }
    initial = newEs;
  };
}
function bindMappedElementsToEvent(event, generator, initialValue, generateInitialElements = true) {
  const e = generateInitialElements ? generator(initialValue) : initialValue;
  event.add(_shellMappedElements(generator, e));
  return e;
}

// SnakeEngine.ts
class SnakeEngine {
  config;
  inputHandler;
  _baseMillisecondsPerUpdate;
  static debugLevel = DebugLevel.LOG;
  static DYNAMIC_TICK_CAP_MS = 100;
  static DYNAMIC_TICK_GROWTH_SPAN = 15;
  onGameOver = new SnakeEvent;
  onGameLost = new SnakeEvent;
  onGameWon = new SnakeEvent;
  onGamePaused = new SnakeEvent;
  onGameResumed = new SnakeEvent;
  onPelletEaten = new SnakeEvent;
  onTickCompleted = new SnakeEvent;
  onTickStarted = new SnakeEvent;
  _isGameOver = false;
  get isGameOver() {
    return this._isGameOver;
  }
  _isGameWon = false;
  get isGameWon() {
    return this._isGameWon;
  }
  _pelletsEaten = 0;
  movesSinceLastPellet = 0;
  pellets = [];
  get currPellets() {
    return [...this.pellets];
  }
  obstacles = [];
  get currObstacles() {
    return [...this.obstacles];
  }
  getValidSpawnLocations() {
    const ret = [];
    const nodes = this.snake.filledNodes;
    for (let x = this.playfieldRect.xMin;x <= this.playfieldRect.xMax; x++) {
      for (let y = this.playfieldRect.yMin;y <= this.playfieldRect.yMax; y++) {
        const p = new Point2d(x, y);
        if (!p.included(this.pellets) && !p.included(this.obstacles) && (!nodes?.length || !nodes.find((e) => p.equals(e))))
          ret.push(p);
      }
    }
    return ret;
  }
  playfieldRect;
  get currentDirection() {
    return this.snake.headDirection;
  }
  _snake;
  get snake() {
    return this._snake;
  }
  get score() {
    return this.snake.snakeLength - (this.config.startingLength || 0);
  }
  constructor(config = EngineConfig.defaultConfig, inputHandler = new InputHandler) {
    this.config = config;
    this.inputHandler = inputHandler;
    this._baseMillisecondsPerUpdate = config.millisecondsPerUpdate;
    this.playfieldRect = RectInt2d.fromDimensionsAndMin(config.gridWidth, config.gridHeight);
    SnakeEngine.debugLevel.print(DebugLevel.INFO, `Config: %o
Playfield: %o`, config, this.playfieldRect);
    this.initGame();
  }
  resetTickRate() {
    this.config.millisecondsPerUpdate = this._baseMillisecondsPerUpdate;
  }
  calculateDynamicTickRate() {
    if (this._baseMillisecondsPerUpdate <= SnakeEngine.DYNAMIC_TICK_CAP_MS)
      return this._baseMillisecondsPerUpdate;
    const growth = Math.max(0, this.snake.snakeLength - this.config.startingLength);
    const progress = Math.min(growth / SnakeEngine.DYNAMIC_TICK_GROWTH_SPAN, 1);
    return this._baseMillisecondsPerUpdate + (SnakeEngine.DYNAMIC_TICK_CAP_MS - this._baseMillisecondsPerUpdate) * progress;
  }
  applyDynamicTickRate() {
    const nextTickRate = this.calculateDynamicTickRate();
    if (Math.abs(this.config.millisecondsPerUpdate - nextTickRate) < 0.5)
      return;
    const wasDriving = !this.isGamePaused;
    if (wasDriving)
      this.engineDriver.stopDriving();
    this.config.millisecondsPerUpdate = nextTickRate;
    if (wasDriving)
      this.engineDriver.startDriving();
  }
  initPointObjectArray(config, objArray, validPoints, clearArray = true) {
    if (clearArray)
      objArray.splice(0);
    if (typeof config.startingObjs === "number") {
      const max = Math.min(validPoints.length, config.startingObjs);
      for (let i = 0;i < max; i++) {
        const index = Math.floor(Math.random() * validPoints.length);
        objArray.push(validPoints[index]);
        validPoints.splice(index, 1);
      }
    } else
      objArray.push(...config.startingObjs.reduce((acc, e) => {
        const v = Point2d.fromIPoint2d(e), i = Point2d.indexIn(v, validPoints);
        if (i >= 0) {
          acc.push(v);
          validPoints.splice(i, 1);
        } else {
          SnakeEngine.debugLevel.print(DebugLevel.WARN, `Config includes invalid point; ignoring invalid point.
	validPoints: %o
	config: %o
	invalidPoint: %o`, validPoints, config, v);
        }
        return acc;
      }, []));
  }
  initGame() {
    this.resetTickRate();
    this.inputHandler.clearInputQueue?.();
    this._snake = Snake_default.fromPreferences(this.config, this.playfieldRect);
    this._isGameOver = this._isGameWon = false;
    this._tickCount = this._pelletsEaten = 0;
    this.lastUpdateTimestamp = this.firstUpdateTimestamp = -1;
    this.inGameTime = 0;
    this.movesSinceLastPellet = 0;
    const t = this.getValidSpawnLocations();
    this.initPointObjectArray(this.config.pelletConfig, this.pellets, t);
    this.initPointObjectArray(this.config.obstacleConfig, this.obstacles, t);
  }
  get isGamePaused() {
    return !this.engineDriver.isDriving;
  }
  engineDriver = new EngineDriver(this);
  startGame() {
    this.resumeGame();
  }
  resumeGame() {
    if (!this.engineDriver.startDriving())
      return;
    this.lastUpdateTimestamp = performance.now();
    SnakeEngine.debugLevel.print(DebugLevel.LOG, "Unpaused at %s", this.lastUpdateTimestamp);
    this.onGameResumed.fire({ engine: this });
  }
  pauseGame() {
    if (!this.engineDriver.stopDriving())
      return;
    this.inGameTime += this.updateLastTimestamp();
    SnakeEngine.debugLevel.print(DebugLevel.LOG, "Paused at %s", this.lastUpdateTimestamp);
    this.onGamePaused.fire({ engine: this });
  }
  transferToNewInstance(other) {
    other.onGameLost.add(...this.onGameLost.clear());
    other.onGameOver.add(...this.onGameOver.clear());
    other.onGamePaused.add(...this.onGamePaused.clear());
    other.onGameResumed.add(...this.onGameResumed.clear());
    other.onGameWon.add(...this.onGameWon.clear());
    other.onPelletEaten.add(...this.onPelletEaten.clear());
    other.onTickCompleted.add(...this.onTickCompleted.clear());
    other.onTickStarted.add(...this.onTickStarted.clear());
  }
  endGame(reason) {
    this.engineDriver.stopDriving();
    this.inputHandler.clearInputQueue?.();
    this._isGameOver = true;
    if (!reason)
      return;
    let args = { engine: this, reason: typeof reason === "string" ? reason : "lost" };
    switch (reason) {
      case "other":
        break;
      case "won":
        this._isGameWon = true;
        this.onGameWon.fire(args);
        break;
      default:
        args = {
          ...args,
          collision: reason
        };
        this.onGameLost.fire(args);
        break;
    }
    this.onGameOver.fire(args);
  }
  _tickCount = 0;
  penultimateUpdateTimestamp = -1;
  lastUpdateTimestamp = -1;
  firstUpdateTimestamp = -1;
  inGameTime = 0;
  get currentOverallTime() {
    return performance.now() - this.firstUpdateTimestamp;
  }
  updateLastTimestamp(timestamp = performance.now()) {
    return -this.lastUpdateTimestamp + (this.lastUpdateTimestamp = timestamp);
  }
  update() {
    if (this.lastUpdateTimestamp < 0) {
      if (this.firstUpdateTimestamp < 0) {
        this.firstUpdateTimestamp = this.lastUpdateTimestamp = performance.now();
        SnakeEngine.debugLevel.print(DebugLevel.LOG, "First update at %s", this.lastUpdateTimestamp);
      }
    }
    const deltaTime = this.updateLastTimestamp();
    this.inGameTime += deltaTime;
    SnakeEngine.debugLevel.print(DebugLevel.INFO, "Delta: %s; time in game: %s", deltaTime, this.inGameTime);
    const args = { engine: this, tickCount: ++this._tickCount, inGameTime: this.inGameTime, timeOverall: this.currentOverallTime };
    this.onTickStarted.fire(args);
    const queuedDirection = this.inputHandler.dequeueNextValidDirection(this.snake.headDirection);
    this.inputHandler.resetState();
    let d = queuedDirection || this.snake.headDirection;
    if (Point2d.equals(this.snake.headDirection, d.opposite)) {
      SnakeEngine.debugLevel.print(DebugLevel.WARN, "Ignoring 180 degree turn");
      d = this.snake.headDirection;
    }
    this.advance(d);
    this.onTickCompleted.fire({ ...args, timeOverall: this.currentOverallTime });
  }
  advance(d = this.currentDirection) {
    const projectedPosition = this.snake.findProjectedHeadPosition(d, this.playfieldRect);
    const eatenIndex = this.pellets.findIndex((e) => e.equals(projectedPosition));
    const intersection = this.obstacles.find((e) => e.equals(projectedPosition)) ?? this.snake.advance(d, eatenIndex > -1);
    if (intersection) {
      this.endGame(intersection);
    } else if (eatenIndex > -1) {
      const args = {
        engine: this,
        pelletCoordinates: this.pellets.splice(eatenIndex, 1)[0],
        snakeLength: this.snake.snakeLength,
        totalEaten: ++this._pelletsEaten,
        movesSinceLast: this.movesSinceLastPellet
      };
      this.movesSinceLastPellet = 0;
      const emptySpaces = this.getValidSpawnLocations();
      if (emptySpaces.length < 1) {
        this.onPelletEaten.fire(args);
        this.endGame("won");
        return;
      } else if (this.pellets.length < this.config.pelletConfig.maxObjs) {
        const newPellet = emptySpaces[randomIndex(emptySpaces)];
        this.pellets.push(newPellet);
        args.newPellets = [newPellet];
      }
      this.applyDynamicTickRate();
      this.onPelletEaten.fire(args);
    } else {
      this.movesSinceLastPellet++;
    }
  }
  renderStats() {
    const initTickArgs = { engine: this, tickCount: this._tickCount, inGameTime: this.inGameTime, timeOverall: this.currentOverallTime };
    const elements = bindMappedElementsToEvent(this.onTickCompleted, (e) => ({
      tickCount: html`<span><span>Turn</span><b>${e.tickCount}</b></span>`,
      snakeLength: html`<span><span>Score</span><b>${e.engine.score}</b></span>`,
      // inGameTime: html`<span><span>In Game Time</span><b>${e.inGameTime}</b></span>`,
      // timeOverall: html`<span><span>Overall Time</span><b>${e.timeOverall}</b></span>`
    }), initTickArgs);
    return html`
    <div id="engine-stats">
      ${elements.tickCount || ""}
      ${elements.snakeLength || ""}
      ${elements.inGameTime || ""}
      ${elements.timeOverall || ""}
    </div>
    `;
  }
}

// SnakeImage.ts
class SnakeImage {
  identifier;
  url;
  sourceRect;
  static imgMap = new Map;
  _isLoaded = false;
  get isLoaded() {
    return this._isLoaded;
  }
  _promise;
  get promise() {
    return this._promise;
  }
  image;
  constructor(identifier, url, sourceRect) {
    this.identifier = identifier;
    this.url = url;
    this.sourceRect = sourceRect;
    this.image = new Image;
    this._promise = new Promise((resolve, _reject) => {
      this.image.addEventListener("load", (e) => {
        this.onLoad(e);
        resolve(this);
      });
      this.image.src = url;
    });
    SnakeImage.imgMap.set(this.identifier, this);
  }
  static loadWithRect(identifier, url, sourceRect) {
    return new SnakeImage(identifier, url, sourceRect).promise;
  }
  static loadWithDimensions(identifier, url, sourceDimensions) {
    return new SnakeImage(identifier, url, sourceDimensions ? RectInt2d.fromDimensionsAndMin(sourceDimensions.x, sourceDimensions.y) : undefined).promise;
  }
  static loadImage(identifier, url, sourceRect) {
    if (sourceRect instanceof RectInt2d)
      return this.loadWithRect(identifier, url, sourceRect);
    return this.loadWithDimensions(identifier, url, sourceRect);
  }
  static loadImageParams({ identifier, url, sourceRect }) {
    return this.loadImage(identifier, url, sourceRect);
  }
  static loadImages(...images) {
    return Promise.all(images.map((e) => this.loadImageParams(e)));
  }
  onLoad(_e) {
    this._isLoaded = true;
  }
  static getImage(identifier) {
    return this.imgMap.get(identifier);
  }
  static tryDrawImage(ctx, identifier, x, y, dimensions) {
    const i = this.imgMap.get(identifier);
    if (i)
      return i.tryDrawImage(ctx, x, y, dimensions);
    return false;
  }
  tryDrawImage(ctx, x, y, dimensions) {
    if (!this.isLoaded)
      return false;
    if (this.sourceRect) {
      ctx.drawImage(this.image, this.sourceRect.xMin, this.sourceRect.yMin, this.sourceRect.width, this.sourceRect.height, x, y, dimensions === undefined ? this.sourceRect.width : dimensions.x, dimensions === undefined ? this.sourceRect.height : dimensions.y);
    } else if (dimensions) {
      ctx.drawImage(this.image, x, y, dimensions.x, dimensions.y);
    } else {
      ctx.drawImage(this.image, x, y);
    }
    return true;
  }
}

// SnakeRenderer.ts
class SnakeRenderer {
  ctx;
  config;
  renderConfig;
  static DEBUG_LEVEL = DebugLevel.INFO;
  get _dbgLvl() {
    return SnakeRenderer.DEBUG_LEVEL;
  }
  static defaultConfig = {
    assets: [
      { identifier: "head", url: "assets/head.svg" },
      { identifier: "body", url: "assets/body.svg" },
      { identifier: "pellet", url: "assets/pelletCentered.svg" },
      { identifier: "bgTile", url: "assets/bgTile.png" },
      { identifier: "corner", url: "assets/bgCornerTopLeft.png" },
      { identifier: "border", url: "assets/bgBorderLeft.png" },
      { identifier: "background", url: "assets/scale.svg" }
    ],
    rotateBorders: true,
    makeOverlay: false,
    makePauseOverlay: true
  };
  engine;
  wrapper;
  get canvas() {
    return this.ctx.canvas;
  }
  get outputSquareWidth() {
    return this.canvas.width <= this.canvas.height ? this.canvas.width : this.canvas.height;
  }
  get renderedCellWidth() {
    return Math.floor(this.outputSquareWidth / this.engine.playfieldRect.width);
  }
  get playfieldRenderedWidth() {
    return this.renderedCellWidth * this.engine.playfieldRect.width;
  }
  get renderedCellRect() {
    return RectInt2d.fromDimensionsAndMin(this.playfieldRenderedWidth, this.playfieldRenderedWidth);
  }
  assetPromise;
  inputDisplayManager;
  constructor(ctx, config = EngineConfig.defaultConfig, renderConfig = SnakeRenderer.defaultConfig) {
    this.ctx = ctx;
    this.config = config;
    this.renderConfig = renderConfig;
    const touchControls = document.querySelector("#touch-container");
    if (touchControls) {
      const inputHandler = new TouchInputHandler({
        up: touchControls.querySelector("#up"),
        down: touchControls.querySelector("#down"),
        left: touchControls.querySelector("#left"),
        right: touchControls.querySelector("#right")
      }, ctx.canvas);
      this.engine = new SnakeEngine(config, inputHandler);
      this.inputDisplayManager = InputDisplay.fromTouchInputHandler(inputHandler);
      const t = DebugLevel.stringify;
      DebugLevel.stringify = false;
      this._dbgLvl.print(DebugLevel.INFO, "Hooked up input display: %o", inputHandler.inputElements);
      DebugLevel.stringify = t;
    } else {
      this.engine = new SnakeEngine(config);
    }
    this.wrapper = new CtxWrapper(this.ctx);
    this.assetPromise = renderConfig.assets ? SnakeImage.loadImages(...renderConfig.assets) : undefined;
  }
  _wasInitialized = false;
  async initGame() {
    await this.assetPromise;
    if (this._wasInitialized)
      this.engine.initGame();
    this.engine.onTickCompleted.add((e) => this.draw(e));
    this.engine.onGameLost.add((_e) => this.endGame(false));
    this.engine.onGameWon.add((_e) => this.endGame(true));
    this.engine.onGamePaused.add((_e) => {
      if (this.renderConfig.makePauseOverlay)
        this.renderPausedOverlay();
    });
    this.engine.onGameResumed.add((_e) => this.draw(_e));
    this._wasInitialized = true;
  }
  startGame() {
    this.engine.startGame();
    this.draw({ engine: this.engine });
  }
  endGame(won) {
    // nothing
    // alert(`Game over: ${won ? "You Won!" : "Sorry, you lost!"}`);
  }
  renderPausedOverlay() {
    this.wrapper.fillSquareFull(0, 0, this.outputSquareWidth, { lineWidth: 2, fillStyle: "rgba(0, 0, 0, .5)" });
  }
  getTileType(x, y) {
    const width = this.engine.playfieldRect.width;
    const height = this.engine.playfieldRect.height;
    const isTopEdge = y === 0;
    const isBottomEdge = y === height - 1;
    const isLeftEdge = x === 0;
    const isRightEdge = x === width - 1;
    if ((isTopEdge || isBottomEdge) && (isLeftEdge || isRightEdge)) {
      return "corner";
    } else if (isTopEdge || isBottomEdge || isLeftEdge || isRightEdge) {
      return "border";
    } else {
      return "tile";
    }
  }
  getRotationAngle(x, y, tileType) {
    const width = this.engine.playfieldRect.width;
    const height = this.engine.playfieldRect.height;
    if (tileType === "corner") {
      if (x === 0 && y === 0)
        return 0;
      if (x === width - 1 && y === 0)
        return 90;
      if (x === width - 1 && y === height - 1)
        return 180;
      if (x === 0 && y === height - 1)
        return 270;
    } else if (tileType === "border") {
      if (x === 0)
        return 0;
      if (y === 0)
        return 90;
      if (x === width - 1)
        return 180;
      if (y === height - 1)
        return 270;
    }
    return 0;
  }
  drawRotatedTile(identifier, x, y, angle) {
    this.ctx.save();
    this.ctx.translate(x + this.renderedCellWidth / 2, y + this.renderedCellWidth / 2);
    this.ctx.rotate(angle * Math.PI / 180);
    const imageDrawn = SnakeImage.tryDrawImage(this.ctx, identifier, -this.renderedCellWidth / 2, -this.renderedCellWidth / 2, { x: this.renderedCellWidth, y: this.renderedCellWidth });
    this.ctx.restore();
    return imageDrawn;
  }
  getSnakeHeadRotationAngle() {
    const direction = this.engine.currentDirection;
    if (direction === Direction2d.left)
      return 0;
    if (direction === Direction2d.right)
      return 180;
    if (direction === Direction2d.up)
      return 90;
    if (direction === Direction2d.down)
      return 270;
    return 0;
  }
  get bgFillColor() {
    if (this.engine.isGameOver) {
      if (this.engine.isGameWon) {
        return "rgba(0, 255, 0, .5)";
      }
      return "rgba(255, 0, 0, .5)";
    }
    return "rgb(50, 88, 146)";
  }
  draw(args) {
    this.wrapper.fillSquareFull(0, 0, this.outputSquareWidth, { lineWidth: 2, fillStyle: this.bgFillColor });
    const backgroundImg = SnakeImage.getImage("background");
    if (backgroundImg && backgroundImg.isLoaded) {
      const pattern = this.ctx.createPattern(backgroundImg.image, "repeat");
      if (pattern) {
        this.ctx.save();
        this.ctx.fillStyle = pattern;
        this.ctx.fillRect(0, 0, this.outputSquareWidth, this.outputSquareWidth);
        this.ctx.restore();
      }
    }
    const snakeSquares = args.engine.snake.filledNodes;
    const snakeSegmentPoints = args.engine.snake.segmentPoints;
    SnakeRenderer.DEBUG_LEVEL.print(DebugLevel.LOG, "Drawn nodes (%s): %o", snakeSquares.length, snakeSquares);
    this.wrapper.autoSave = this.wrapper.autoRestore = true;
    for (let i = 0, offsetWidth = 0;i < this.engine.playfieldRect.width; i++, offsetWidth = i * this.renderedCellWidth) {
      for (let j = 0, offsetHeight = 0;j < this.engine.playfieldRect.height; j++, offsetHeight = j * this.renderedCellWidth) {
        let backgroundDrawn = false;
        if (this.renderConfig.rotateBorders) {
          const tileType = this.getTileType(i, j);
          switch (tileType) {
            case "border":
            case "corner":
              backgroundDrawn = this.drawRotatedTile(tileType, offsetWidth, offsetHeight, this.getRotationAngle(i, j, tileType));
              break;
            default:
              backgroundDrawn = SnakeImage.tryDrawImage(this.ctx, "bgTile", offsetWidth, offsetHeight, { x: this.renderedCellWidth, y: this.renderedCellWidth });
              break;
          }
        } else {
          backgroundDrawn = SnakeImage.tryDrawImage(this.ctx, "bgTile", offsetWidth, offsetHeight, { x: this.renderedCellWidth, y: this.renderedCellWidth });
        }
        if (!backgroundDrawn) {
          this.wrapper.strokeSquareFull(offsetWidth, offsetHeight, this.renderedCellWidth, { fillStyle: "rgba(255, 255, 255, .5)" });
        }
        if (snakeSquares.find((e) => e.x === i && e.y === j)) {
          const isHead = this.engine.snake.head.equals({ x: i, y: j });
          const isSegment = snakeSegmentPoints.some((e) => e.equals({ x: i, y: j }));
          let imageDrawn = false;
          if (isHead) {
            const headAngle = this.getSnakeHeadRotationAngle();
            imageDrawn = this.drawRotatedTile("head", offsetWidth, offsetHeight, headAngle);
          } else {
            imageDrawn = SnakeImage.tryDrawImage(this.ctx, "body", offsetWidth, offsetHeight, { x: this.renderedCellWidth, y: this.renderedCellWidth });
          }
          if (!imageDrawn) {
            this.wrapper.fillSquareFull(offsetWidth, offsetHeight, this.renderedCellWidth, { lineWidth: 2, fillStyle: isHead ? "red" : isSegment ? "blue" : "green" });
          }
        } else if (this.engine.currPellets.find((e) => e?.equals({ x: i, y: j }))) {
          if (!SnakeImage.tryDrawImage(this.ctx, "pellet", offsetWidth, offsetHeight, { x: this.renderedCellWidth, y: this.renderedCellWidth }))
            this.wrapper.fillSquareFull(offsetWidth, offsetHeight, this.renderedCellWidth, { lineWidth: 2, fillStyle: "yellow" });
        } else if (this.engine.currObstacles.find((e) => e?.equals({ x: i, y: j }))) {
          if (!SnakeImage.tryDrawImage(this.ctx, "wall", offsetWidth, offsetHeight, { x: this.renderedCellWidth, y: this.renderedCellWidth }))
            this.wrapper.fillSquareFull(offsetWidth, offsetHeight, this.renderedCellWidth, { lineWidth: 2, fillStyle: "black" });
        }
      }
    }
    if (this.renderConfig.makeOverlay && this.engine.isGameOver)
      this.wrapper.fillSquareFull(0, 0, this.outputSquareWidth, { lineWidth: 2, fillStyle: this.bgFillColor });
    if (!this.renderConfig.rotateBorders)
      this.wrapper.strokeSquareFull(0, 0, this.outputSquareWidth, { lineWidth: 2, strokeStyle: "black" });
    this.wrapper.autoSave = this.wrapper.autoRestore = false;
  }
  drawGrid() {
    this.wrapper.autoSave = true;
    this.wrapper.autoRestore = false;
    this.wrapper.strokeSquareFull(0, 0, this.outputSquareWidth, { lineWidth: 2, strokeStyle: "black" });
    this.wrapper.autoSave = false;
    this.wrapper.autoRestore = false;
    for (let i = 0;i < this.engine.playfieldRect.width; i++) {
      for (let j = 0;j < this.engine.playfieldRect.height; j++) {
        this.wrapper.strokeSquareFull(i * this.renderedCellWidth, j * this.renderedCellWidth, this.renderedCellWidth);
      }
    }
  }
}

class CtxWrapper {
  ctx;
  autoRestore;
  autoSave;
  saveStack;
  static autoSave = false;
  static autoRestore = false;
  static prepRect(ctx, x, y, width, height, { strokeStyle, fillStyle, lineWidth }, wrapperSettings = { autoRestore: this.autoRestore, autoSave: this.autoSave }) {
    if (wrapperSettings.autoSave ?? this.autoSave)
      ctx.save();
    if (strokeStyle)
      ctx.strokeStyle = strokeStyle;
    if (fillStyle)
      ctx.fillStyle = fillStyle;
    if (lineWidth)
      ctx.lineWidth = lineWidth;
    const offset = ctx.lineWidth / 2;
    x += offset;
    y += offset;
    width -= ctx.lineWidth;
    height -= ctx.lineWidth;
    return { x, y, width, height, w: width, h: height };
  }
  static prepSquare(ctx, x, y, width, options, wrapperSettings = { autoRestore: this.autoRestore, autoSave: this.autoSave }) {
    return this.prepRect(ctx, x, y, width, width, options, wrapperSettings);
  }
  static strokeRectFull(ctx, x, y, width, height, { strokeStyle, lineWidth }, wrapperSettings = { autoRestore: this.autoRestore, autoSave: this.autoSave }) {
    const p = this.prepRect(ctx, x, y, width, height, { strokeStyle, lineWidth }, wrapperSettings);
    ctx.strokeRect(p.x, p.y, p.width, p.height);
    if (wrapperSettings.autoRestore ?? this.autoRestore)
      ctx.restore();
  }
  static strokeSquareFull(ctx, x, y, width, { strokeStyle, lineWidth }, wrapperSettings = { autoRestore: this.autoRestore, autoSave: this.autoSave }) {
    const p = this.prepRect(ctx, x, y, width, width, { strokeStyle, lineWidth }, wrapperSettings);
    ctx.strokeRect(p.x, p.y, p.width, p.height);
    if (wrapperSettings.autoRestore ?? this.autoRestore)
      ctx.restore();
  }
  static fillRectFull(ctx, x, y, width, height, { fillStyle, lineWidth }, wrapperSettings = { autoRestore: this.autoRestore, autoSave: this.autoSave }) {
    const p = this.prepRect(ctx, x, y, width, height, { fillStyle, lineWidth }, wrapperSettings);
    ctx.fillRect(p.x, p.y, p.width, p.height);
    if (wrapperSettings.autoRestore ?? this.autoRestore)
      ctx.restore();
  }
  static fillSquareFull(ctx, x, y, width, { fillStyle, lineWidth }, wrapperSettings = { autoRestore: this.autoRestore, autoSave: this.autoSave }) {
    const p = this.prepRect(ctx, x, y, width, width, { fillStyle, lineWidth }, wrapperSettings);
    ctx.fillRect(p.x, p.y, p.width, p.height);
    if (wrapperSettings.autoRestore ?? this.autoRestore)
      ctx.restore();
  }
  static clearRectFull(ctx, x, y, width, height, { strokeStyle, lineWidth }, wrapperSettings = { autoRestore: this.autoRestore, autoSave: this.autoSave }) {
    const p = this.prepRect(ctx, x, y, width, height, { strokeStyle, lineWidth }, wrapperSettings);
    ctx.clearRect(p.x, p.y, p.width, p.height);
    if (wrapperSettings.autoRestore ?? this.autoRestore)
      ctx.restore();
  }
  static clearSquareFull(ctx, x, y, width, { strokeStyle, lineWidth }, wrapperSettings = { autoRestore: this.autoRestore, autoSave: this.autoSave }) {
    const p = this.prepRect(ctx, x, y, width, width, { strokeStyle, lineWidth }, wrapperSettings);
    ctx.clearRect(p.x, p.y, p.width, p.height);
    if (wrapperSettings.autoRestore ?? this.autoRestore)
      ctx.restore();
  }
  onSave() {
    if (this.autoSave)
      this.saveStack++;
  }
  onRestore() {
    if (this.autoRestore)
      this.saveStack--;
  }
  save() {
    this.ctx.save();
    this.onSave();
  }
  restore() {
    this.ctx.restore();
    this.onRestore();
  }
  constructor(ctx, autoRestore = true, autoSave = true, saveStack = 0) {
    this.ctx = ctx;
    this.autoRestore = autoRestore;
    this.autoSave = autoSave;
    this.saveStack = saveStack;
  }
  prepRect(x, y, width, height, options = {}) {
    this.onSave();
    return CtxWrapper.prepRect(this.ctx, x, y, width, height, options, this);
  }
  strokeRectFull(x, y, width, height, options = {}) {
    this.onSave();
    CtxWrapper.strokeRectFull(this.ctx, x, y, width, height, options, this);
    this.onRestore();
  }
  strokeSquareFull(x, y, width, options = {}) {
    this.onSave();
    CtxWrapper.strokeSquareFull(this.ctx, x, y, width, options, this);
    this.onRestore();
  }
  fillSquareFull(x, y, width, options = {}) {
    this.onSave();
    CtxWrapper.fillSquareFull(this.ctx, x, y, width, options, this);
    this.onRestore();
  }
}
var SnakeRenderer_default = SnakeRenderer;

// index.ts
/* var canvas = document.querySelector("canvas") ?? (() => {
  const c = document.createElement("canvas");
  document.body.prepend(c);
  return c;
})();
canvas.width = 300;
canvas.height = 300;
var ctx = canvas.getContext("2d");
if (!ctx) {
  throw Error("Failed to retrieve canvas context.");
}
var state = EngineConfig.toUI(EngineConfig.defaults, initialize);
var lastEngineStats;
function initialize(cfg) {
  if (lastEngineStats)
    lastEngineStats.remove();
  const r = new SnakeRenderer_default(ctx, cfg);
  lastEngineStats = r.engine.renderStats();
  canvas.insertAdjacentElement("afterend", lastEngineStats);
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  r.initGame().then(() => {
    const _t = (e) => {
      if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement)
        return;
      if (e.key === " ") {
        r.startGame();
        document.removeEventListener("keyup", _t);
      }
    };
    document.addEventListener("keyup", _t);
    r.draw({ engine: r.engine });
  }).catch((error) => {
    console.error("Failed to load game assets:", error);
  });
}
canvas.parentElement.appendChild(state.form);
initialize(state.defaults); */

export {
  DebugLevel,
  NONE,
  ERROR,
  WARN,
  INFO,
  LOG,
  DEBUG,

  EngineDriver,

  SnakeEvent,

  html,

  InputAction,
  InputHandler,
  TouchInputHandler,
  InputDisplay,


  Point2d as Point,
  Point2d,
  Direction2d as Direction,
  Direction2d,
  RectInt2d as RectInt,
  RectInt2d,

  Snake,
  Snake_default,

  SnakeEngine,

  SnakeImage,

  SnakeRenderer,
  SnakeRenderer_default,

  EngineConfig,
  randomIndex,
  NodeGeneration,
  /*
  UiStat,
  bindToEvent,
  bindElementsToEvent, */
  bindMappedElementsToEvent,
};
