define(["require", "exports"], function (require, exports) {
    var EventEmitter = (function () {
        function EventEmitter() {
            this.events = {};
        }
        EventEmitter.prototype.on = function (name, fn) {
            this.events[name] = this.events[name] || [];
            this.events[name].push(fn);
        };
        EventEmitter.prototype.trigger = function (name, args) {
            var _this = this;
            this.events[name] = this.events[name] || [];
            args = args || [];
            this.events[name].forEach(function (fn) { fn.apply(_this, args); });
        };
        return EventEmitter;
    })();
    return EventEmitter;
});
