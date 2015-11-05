define(["require", "exports"], function (require, exports) {
    /** Minimal EventEmitter interface that is molded against the Node.js
     * EventEmitter interface. converted to typescript from https://github.com/primus/eventemitter3*/
    var EventEmitter = (function () {
        function EventEmitter() {
            /** Holds the assigned EventEmitters by name*/
            this._events = null;
            this.off = null;
            this.addListener = null;
            this.cancel = null;
            this.cancelId = null;
            // Alias methods names because people roll like that.
            this.off = this.removeListener;
            this.addListener = this.on;
        }
        /** Emit an event to all registered event listeners. */
        EventEmitter.prototype.emit = function (event, a1, a2, a3, a4, a5) {
            if (!this._events || !this._events[event])
                return false;
            var listeners = this._events[event], len = arguments.length, args, i;
            if ('function' === typeof listeners.fn) {
                if (listeners.once)
                    this.removeListener(event, listeners.fn, undefined, true);
                if (len === 1)
                    return listeners.fn.call(listeners.context), true;
                else if (len === 2)
                    return listeners.fn.call(listeners.context, a1), true;
                else if (len === 3)
                    return listeners.fn.call(listeners.context, a1, a2), true;
                else if (len === 4)
                    return listeners.fn.call(listeners.context, a1, a2, a3), true;
                else if (len === 5)
                    return listeners.fn.call(listeners.context, a1, a2, a3, a4), true;
                else if (len === 6)
                    return listeners.fn.call(listeners.context, a1, a2, a3, a4, a5), true;
                for (i = 1, args = new Array(len - 1); i < len; i++) {
                    args[i - 1] = arguments[i];
                }
                listeners.fn.apply(listeners.context, args);
            }
            else {
                var length = listeners.length, j;
                for (i = 0; i < length; i++) {
                    if (listeners[i].once)
                        this.removeListener(event, listeners[i].fn, undefined, true);
                    if (len === 1)
                        listeners[i].fn.call(listeners[i].context);
                    if (len === 2)
                        listeners[i].fn.call(listeners[i].context, a1);
                    if (len === 3)
                        listeners[i].fn.call(listeners[i].context, a1, a2);
                    else if (!args)
                        for (j = 1, args = new Array(len - 1); j < len; j++) {
                            args[j - 1] = arguments[j];
                        }
                    listeners[i].fn.apply(listeners[i].context, args);
                }
            }
            return true;
        };
        /** Return a list of assigned event listeners. event: The events that should be listed. exists: We only need to know if there are listeners. */
        EventEmitter.prototype.listeners = function (event, exists) {
            var available = this._events && this._events[event];
            if (exists)
                return !!available;
            if (!available)
                return [];
            if (available.fn)
                return [available.fn];
            for (var i = 0, l = available.length, ee = new Array(l); i < l; i++) {
                ee[i] = available[i].fn;
            }
            return ee;
        };
        /** Register a new EventListener for the given event. event: Name of the event. fn: Callback function. [context=this] The context of the function. */
        EventEmitter.prototype.on = function (event, fn, context) {
            var listener = new EE(fn, context || this);
            if (!this._events)
                this._events = Object.create(null);
            if (!this._events[event])
                this._events[event] = listener;
            else {
                if (!this._events[event].fn)
                    this._events[event].push(listener);
                else
                    this._events[event] = [this._events[event], listener];
            }
            return this;
        };
        /** Add an EventListener that's only called once. event: Name of the event. fn: Callback function. [context=this] The context of the function. */
        EventEmitter.prototype.once = function (event, fn, context) {
            var listener = new EE(fn, context || this, true);
            if (!this._events)
                this._events = Object.create(null);
            if (!this._events[event])
                this._events[event] = listener;
            else {
                if (!this._events[event].fn)
                    this._events[event].push(listener);
                else
                    this._events[event] = [this._events[event], listener];
            }
            return this;
        };
        /** Remove event listeners. event: The event we want to remove.   fn: The listener that we need to find.
         * cntxt: Only remove listeners matching this context.   once: Only remove once listeners.  */
        EventEmitter.prototype.removeListener = function (event, fn, cntxt, once) {
            if (!this._events || !this._events[event])
                return this;
            var lstnrs = this._events[event], events = [];
            if (fn) {
                if (lstnrs.fn) {
                    if (lstnrs.fn !== fn || (once && !lstnrs.once) || (cntxt && lstnrs.context !== cntxt))
                        events.push(lstnrs);
                }
                else {
                    for (var i = 0, length = lstnrs.length; i < length; i++) {
                        if (lstnrs[i].fn !== fn || (once && !lstnrs[i].once) || (cntxt && lstnrs[i].context !== cntxt))
                            events.push(lstnrs[i]);
                    }
                }
            }
            // Reset the array, or remove it completely if we have no more listeners.
            if (events.length)
                this._events[event] = events.length === 1 ? events[0] : events;
            else
                delete this._events[event];
            return this;
        };
        /** Remove all listeners or only the listeners for the specified event. event: The event want to remove all listeners for. */
        EventEmitter.prototype.removeAllListeners = function (event) {
            if (!this._events)
                return this;
            if (event)
                delete this._events[event];
            else
                this._events = Object.create(null);
            return this;
        };
        return EventEmitter;
    })();
    /** Representation of a single EventEmitter function. */
    var EE = (function () {
        function EE(fn, context, once) {
            this.fn = null;
            this.context = null;
            this.once = false;
            this.fn = fn;
            this.context = context;
            this.once = once || false;
        }
        return EE;
    })();
    return EventEmitter;
});
