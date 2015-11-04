/** Minimal EventEmitter interface that is molded against the Node.js
 * EventEmitter interface.*/
class EventEmitter {

    /** Holds the assigned EventEmitters by name*/
    private _events = null;

    off = null;
    addListener = null;

    constructor() {
        // Alias methods names because people roll like that.
        this.off = this.removeListener;
        this.addListener = this.on;

    }

    /** Emit an event to all registered event listeners. */
    emit(event:string, a1:any, a2:any, a3:any, a4:any, a5:any):boolean {

        if (!this._events || !this._events[event]) return false;

        var listeners = this._events[event], len = arguments.length, args, i;

        if ('function' === typeof listeners.fn) {
            if (listeners.once) this.removeListener(event, listeners.fn, undefined, true);

            if (len === 1) return listeners.fn.call(listeners.context), true;
            else if (len === 2) return listeners.fn.call(listeners.context, a1), true;
            else if (len === 3) return listeners.fn.call(listeners.context, a1, a2), true;
            else if (len === 4) return listeners.fn.call(listeners.context, a1, a2, a3), true;
            else if (len === 5) return listeners.fn.call(listeners.context, a1, a2, a3, a4), true;
            else if (len === 6) return listeners.fn.call(listeners.context, a1, a2, a3, a4, a5), true;

            for (i = 1, args = new Array(len - 1); i < len; i++) { args[i - 1] = arguments[i]; }

            listeners.fn.apply(listeners.context, args);
        } else {
            var length = listeners.length, j;

            for (i = 0; i < length; i++) {
                if (listeners[i].once) this.removeListener(event, listeners[i].fn, undefined, true);

                if (len === 1) listeners[i].fn.call(listeners[i].context);
                if (len === 2) listeners[i].fn.call(listeners[i].context, a1);
                if (len === 3) listeners[i].fn.call(listeners[i].context, a1, a2);
                else if (!args) for (j = 1, args = new Array(len - 1); j < len; j++) {
                    args[j - 1] = arguments[j];
                }

                listeners[i].fn.apply(listeners[i].context, args);
            }
        }

        return true;
    }

    /** Return a list of assigned event listeners.
     * @param event The events that should be listed.
     * @param exists We only need to know if there are listeners.
     */
    listeners(event:string, exists:boolean):Array<any> | boolean {
        var available:any = this._events && this._events[event];

        if (exists) return !!available;
        if (!available) return [];
        if (available.fn) return [available.fn];

        for (var i = 0, l = available.length, ee = new Array(l); i < l; i++) {
            ee[i] = available[i].fn;
        }

        return ee;
    }

    /**
     * Register a new EventListener for the given event.
     * @param event Name of the event.
     * @param fn Callback function.
     * @param [context=this] The context of the function.
     */
    on(event:string, fn:Function, context:any) {
        var listener = new EE(fn, context || this);

        if (!this._events) this._events = Object.create(null);
        if (!this._events[event]) this._events[event] = listener;
        else {
            if (!this._events[event].fn) this._events[event].push(listener);
            else this._events[event] = [this._events[event], listener];
        }

        return this;
    }

    /** Add an EventListener that's only called once.
     * @param event Name of the event.
     * @param {Function} fn Callback function.
     * @param [context=this] The context of the function.
     */
    once(event:string, fn, context:any) {
        var listener = new EE(fn, context || this, true);

        if (!this._events) this._events = Object.create(null);
        if (!this._events[event]) this._events[event] = listener;
        else {
            if (!this._events[event].fn) this._events[event].push(listener);
            else this._events[event] = [
                this._events[event], listener
            ];
        }

        return this;
    }

    /** Remove event listeners.
     * @param {String} event The event we want to remove.
     * @param {Function} fn The listener that we need to find.
     * @param context Only remove listeners matching this context.
     * @param {Boolean} once Only remove once listeners.
     */
    removeListener(event, fn, context:any, once) {

        if (!this._events || !this._events[event]) return this;

        var listeners = this._events[event]
            , events = [];

        if (fn) {
            if (listeners.fn) {
                if (
                    listeners.fn !== fn
                    || (once && !listeners.once)
                    || (context && listeners.context !== context)
                ) {
                    events.push(listeners);
                }
            } else {
                for (var i = 0, length = listeners.length; i < length; i++) {
                    if (
                        listeners[i].fn !== fn
                        || (once && !listeners[i].once)
                        || (context && listeners[i].context !== context)
                    ) {
                        events.push(listeners[i]);
                    }
                }
            }
        }

        // Reset the array, or remove it completely if we have no more listeners.
        if (events.length) this._events[event] = events.length === 1 ? events[0] : events;
        else delete this._events[event];

        return this;
    }

    /** Remove all listeners or only the listeners for the specified event.
     * @param {String} event The event want to remove all listeners for.
     */
    removeAllListeners(event:string) {
        if (!this._events) return this;

        if (event) delete this._events[event];
        else this._events = Object.create(null);

        return this;
    }


}

/** Representation of a single EventEmitter function. */
class EE {
    fn = null;
    context = null;
    once = false;

    constructor(fn:Function, context:any, once?:boolean){
        this.fn = fn;
        this.context = context;
        this.once = once || false;
    }
}

export = EventEmitter;
