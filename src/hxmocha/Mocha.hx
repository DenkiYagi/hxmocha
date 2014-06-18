package hxmocha;

import haxe.ds.Option;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.FieldKind;

class Mocha {
    static var _: Dynamic;
    static function __init__() {
        #if !macro
        _ = untyped __js__("(typeof window) ? window : global");

        var p = _.expect.Assertion.prototype;
        p.enumEqual = function (obj) {
            var self = untyped __js__("this");
            self.assert(
                Type.enumEq(obj, self.obj),
                function () return 'expected ${Std.string(self.obj)} to equal ${Std.string(obj)}',
                function () return 'expected ${Std.string(self.obj)} to not equal ${Std.string(obj)}'
            );
        }
        #end
    }

    public static inline function describe(title: String, fn: Void -> Void): Void {
        _.describe(title, fn);
    }

    public static inline function describeOnly(title: String, fn: Void -> Void): Void {
        _.describe.only(title, fn);
    }

    public static inline function describeSkip(title: String, fn: Void -> Void): Void {
        _.describe.skip(title, fn);
    }

    @:overload(function (title: String, ?fn: (Void -> Void) -> Void): Void{})
    public static inline function it(title: String, ?fn: Void -> Void): Void {
        _.it(title, fn);
    }

    @:overload(function (fn: (Void -> Void) -> Void): Void{})
    public static inline function before(fn: Void -> Void): Void {
        _.before(fn);
    }

    @:overload(function (fn: (Void -> Void) -> Void): Void{})
    public static inline function after(fn: Void -> Void): Void {
        _.after(fn);
    }

    @:overload(function (fn: (Void -> Void) -> Void): Void{})
    public static inline function beforeEach(fn: Void -> Void): Void {
        _.beforeEach(fn);
    }

    @:overload(function (fn: (Void -> Void) -> Void): Void{})
    public static inline function afterEach(fn: Void -> Void): Void {
        _.afterEach(fn);
    }

    public static inline function expect(value: Dynamic): DefaultAssertion {
        return _.expect(value);
    }

    macro public static function addSpec(specClass: Expr) {
        function first<T>(array: Array<T>, fn:  T -> Bool): Option<T> {
            for (x in array) {
                if (fn(x)) return Some(x);
            }
            return None;
        }

        function map<A, B>(x: Option<A>, fn: A -> B): Option<B> {
            return switch (x) {
                case Some(a): Some(fn(a));
                case None: None;
            }
        }

        function flatMap<A, B>(x: Option<A>, fn: A -> Option<B>): Option<B> {
            return switch (x) {
                case Some(a): fn(a);
                case None: None;
            }
        }

        function getClassType(expr: Expr): Option<ClassType> {
            return switch (expr.expr) {
                case EConst(CIdent(clsName)):
                    switch (Context.getType(clsName)) {
                        case TInst(refClass, _): Some(refClass.get());
                        case _: None;
                    }
                case _:
                    None;
            }
        }

        function getDescribeTitle(ct: ClassType): String {
            return switch (first(ct.meta.get(), function (x) {
                return x.name == ":describe" && x.params.length == 1;
            })) {
                case Some(meta):
                    switch (meta.params[0].expr) {
                        case EConst(CString(x)): x;
                        case _: ct.name;
                    }
                case _:
                    ct.name;
            }
        }

        function getDescribeMethods(ct: ClassType): Array<{method: String, describe: Option<String>}> {
            return ct.statics.get().filter(function (x) {
                return switch(x.kind) {
                    case FieldKind.FMethod(_): x.isPublic;
                    case _: false;
                }
            }).map(function (x) {
                var meta = first(x.meta.get(), function (y) return y.name == ":describe");
                return {
                    method: x.name,
                    describe: flatMap(meta, function (x) {
                        return switch (x.params) {
                            case [{expr: EConst(CString(y)), pos: _}]: Some(y);
                            case _: None;
                        }
                    })
                };
            });
        }

        return switch (getClassType(specClass)) {
            case Some(clsType):
                var expr = getDescribeMethods(clsType).map(function (x) {
                    var method = x.method;
                    return switch (x.describe) {
                        case Some(title):
                            macro Mocha.describe($v{title}, ${specClass}.$method);
                        case None:
                            macro Mocha.describe($v{method}, ${specClass}.$method);
                    }
                });

                var title = getDescribeTitle(clsType);
                macro Mocha.describe($v{title}, function () {
                    $a{expr};
                });
            case None:
                macro { };
        }
    }
}

extern class Assertion {
    var obj(default, never): Dynamic;

    function ok(): Void;

    function equal(expected: Dynamic): Void;

    function eql(expected: Dynamic): Void;

    function enumEqual<T: EnumValue>(expected: T): Void;

    @:overload(function (expected: {}): Void{})
    function a(expected: String): Void;
    @:overload(function (expected: {}): Void{})
    function an(expected: String): Void;

    function match(expected: EReg): Void;

    function contain(value: Dynamic): Void;

    function length(expected: Int): Void;

    function empty(): Void;

    function property(name: String, ?ValueType: Dynamic): Void;

    function key(name: String): Void;

    function keys(names: Array<String>): Void;

    @:overload(function (f: Dynamic -> Void): Void{})
    @:overload(function (pattern: EReg): Void{})
    function throwException(): Void;
    @:overload(function (f: Dynamic -> Void): Void{})
    @:overload(function (pattern: EReg): Void{})
    function throwError(): Void;

    @:overload(function (start: Float, finish: Float): Void{})
    function within(start: Int, finish: Int): Void;

    @:overload(function (value : Float): Void{})
    function greaterThan(value: Int): Void;
    @:overload(function (value : Float): Void{})
    function above(value: Int): Void;

    @:overload(function (value : Float): Void{})
    function lessThan(value: Int): Void;
    @:overload(function (value : Float): Void{})
    function below(value: Int): Void;

    function fail(?message: String): Void;
}

extern class DefaultAssertion extends Assertion {
    var not(default, null): NotAssertion;
    var to(default, null): ToAssertion;
    var only(default, null): OnlyAssertion;
    var have(default, null): HaveAssertion;
    var be(default, null): BeAssertion;
}

extern class NotAssertion extends Assertion {
    var to(default, null): ToAssertion;
    var be(default, null): BeAssertion;
    var have(default, null): HaveAssertion;
    var include(default, null): Assertion;
    var only(default, null): HaveAssertion;
}

extern class ToAssertion extends Assertion {
    var be(default, null): BeAssertion;
    var have(default, null): HaveAssertion;
    var include(default, null): Assertion;
    var only(default, null): OnlyAssertion;
    var not(default, null): NotAssertion;
}

extern class OnlyAssertion extends Assertion {
    var have(default, null): HaveAssertion;
}

extern class HaveAssertion extends Assertion {
    var own(default, null): Assertion;
}

typedef BeAssertion = Assertion;
