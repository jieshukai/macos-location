{
  "targets": [
    {
      "target_name": "bindings",
      "conditions": [
        ["OS == 'mac'", {
          "sources": [
            "src/LocationManager.mm",
            "src/CLLocationBindings.mm"
          ],
          "link_settings": {
            "libraries": [
              "CoreLocation.framework"
            ]
          }
        }, {
          "type": "none"  // 非macOS平台不编译此目标
        }]
      ]
    }
  ]
}
