#include <math.h>
#include <node.h>
#include <v8.h>
#import <CoreLocation/CoreLocation.h>
#import "LocationManager.h"

using namespace v8;
using namespace node;

// 辅助函数：将 MaybeLocal<String> 转换为 Local<String>
Local<String> createString(Isolate* isolate, const char* value) {
    MaybeLocal<String> maybeStr = String::NewFromUtf8(isolate, value);
    if (maybeStr.IsEmpty()) {
        isolate->ThrowException(Exception::TypeError(
            String::NewFromUtf8(isolate, "Failed to create string").ToLocalChecked()
        ));
        return Local<String>();
    }
    return maybeStr.ToLocalChecked();
}

void getCurrentPosition(const FunctionCallbackInfo<Value>& args) {
    Isolate* isolate = args.GetIsolate();
    HandleScope scope(isolate);
    Local<Context> context = isolate->GetCurrentContext(); // 获取当前上下文

    LocationManager* locationManager = [[LocationManager alloc] init];

    if (args.Length() == 1) {
        if (args[0]->IsObject()) {
            // 修复：ToObject 需要传入 Context，且返回 MaybeLocal<Object>
            MaybeLocal<Object> maybeOptions = args[0]->ToObject(context);
            if (maybeOptions.IsEmpty()) {
                isolate->ThrowException(Exception::TypeError(
                    createString(isolate, "Invalid options object")
                ));
                return;
            }
            Local<Object> options = maybeOptions.ToLocalChecked();

            // 处理 maximumAge
            Local<String> maximumAgeKey = createString(isolate, "maximumAge");
            if (options->Has(context, maximumAgeKey).FromJust()) {
                MaybeLocal<Value> maximumAgeValue = options->Get(context, maximumAgeKey);
                if (!maximumAgeValue.IsEmpty()) {
                    Maybe<double> maybeMaxAge = maximumAgeValue.ToLocalChecked()->NumberValue(context);
                    if (maybeMaxAge.IsJust()) {
                        locationManager.maximumAge = fmax(100, maybeMaxAge.FromJust());
                        locationManager.maximumAge /= 1000.0;
                    }
                }
            }

            // 处理 enableHighAccuracy - 修复 BooleanValue 调用
            Local<String> enableHighAccuracyKey = createString(isolate, "enableHighAccuracy");
            if (options->Has(context, enableHighAccuracyKey).FromJust()) {
                MaybeLocal<Value> accuracyValue = options->Get(context, enableHighAccuracyKey);
                if (!accuracyValue.IsEmpty()) {
                    // 修复点：BooleanValue 接受 Isolate* 并返回 bool
                    locationManager.enableHighAccuracy = accuracyValue.ToLocalChecked()->BooleanValue(isolate);
                }
            }

            // 处理 timeout
            Local<String> timeoutKey = createString(isolate, "timeout");
            if (options->Has(context, timeoutKey).FromJust()) {
                MaybeLocal<Value> timeoutValue = options->Get(context, timeoutKey);
                if (!timeoutValue.IsEmpty()) {
                    Maybe<double> maybeTimeout = timeoutValue.ToLocalChecked()->NumberValue(context);
                    if (maybeTimeout.IsJust()) {
                        locationManager.timeout = maybeTimeout.FromJust();
                    }
                }
            }
        }
    }

    if (![CLLocationManager locationServicesEnabled]) {
        isolate->ThrowException(
            Exception::TypeError(createString(isolate, "CLocationErrorNoLocationService"))
        );
        return;
    }

    CLLocation* location = [locationManager getCurrentLocation];

    if ([locationManager hasFailed]) {
        switch (locationManager.errorCode) {
            case kCLErrorDenied:
                isolate->ThrowException(
                    Exception::TypeError(createString(isolate, "CLocationErrorLocationServiceDenied"))
                );
                return;
            case kCLErrorGeocodeCanceled:
                isolate->ThrowException(
                    Exception::TypeError(createString(isolate, "CLocationErrorGeocodeCanceled"))
                );
                return;
            case kCLErrorLocationUnknown:
                isolate->ThrowException(
                    Exception::TypeError(createString(isolate, "CLocationErrorLocationUnknown"))
                );
                return;
            default:
                isolate->ThrowException(
                    Exception::TypeError(createString(isolate, "CLocationErrorLookupFailed"))
                );
                return;
        }
    }

    Local<Object> obj = Object::New(isolate);
    obj->Set(context, createString(isolate, "latitude"),
             Number::New(isolate, location.coordinate.latitude)).FromJust();
    obj->Set(context, createString(isolate, "longitude"),
             Number::New(isolate, location.coordinate.longitude)).FromJust();
    obj->Set(context, createString(isolate, "altitude"),
             Number::New(isolate, location.altitude)).FromJust();
    obj->Set(context, createString(isolate, "horizontalAccuracy"),
             Number::New(isolate, location.horizontalAccuracy)).FromJust();
    obj->Set(context, createString(isolate, "verticalAccuracy"),
             Number::New(isolate, location.verticalAccuracy)).FromJust();

    NSTimeInterval seconds = [location.timestamp timeIntervalSince1970];
    obj->Set(context, createString(isolate, "timestamp"),
             Number::New(isolate, (NSInteger)ceil(seconds * 1000))).FromJust();

    args.GetReturnValue().Set(obj);
}

void Initialise(Local<Object> exports) {
    NODE_SET_METHOD(exports, "getCurrentPosition", getCurrentPosition);
}

NODE_MODULE(macos_clocation_wrapper, Initialise)
