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
          "type": "none"
        }]
      ]
    }
  ]
}
