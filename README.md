# PhotosHelper

[![CI Status](http://img.shields.io/travis/DroidsOnRoids/PhotosHelper.svg?style=flat)](https://travis-ci.org/DroidsOnRoids/PhotosHelper)
[![Version](https://img.shields.io/cocoapods/v/PhotosHelper.svg?style=flat)](http://cocoapods.org/pods/PhotosHelper)
[![License](https://img.shields.io/cocoapods/l/PhotosHelper.svg?style=flat)](http://cocoapods.org/pods/PhotosHelper)
[![Platform](https://img.shields.io/cocoapods/p/PhotosHelper.svg?style=flat)](http://cocoapods.org/pods/PhotosHelper)

<p align="center">
<img src="Pod/Logo_square.png" alt="Droids On Roids logo"/>
</p>

## Usage

```swift
PhotosHelper.saveImage(image)
PhotosHelper.saveImage(image, toAlbum: "Album Name")
PhotosHelper.saveImage(image, toAlbum: "Album name", completion: { (success, error) in

})
```

Note: Trying to create an album with a name that already exists won't overwrite anything.
```swift
PhotosHelper.createAlbum(completion: { (album) -> () in

})
PhotosHelper.createAlbum("Album Name", completion: { (album) -> () in

})
```

Note: If an album with the specified name does not exist, it is created and then returned normally.
```swift
PhotosHelper.getAlbum(completion: { (album) -> () in

})
PhotosHelper.getAlbum("Album Name", completion: { (album) -> () in

})
```

Note: *Default options specify: ordering newest first, in original size, synchronously, in the best quality and scaled AspectFill.*
```swift
PhotosHelper.getImagesFromAlbum(completion: { (result) -> () in

})
```

```swift
var options = PhotosHelper.ImageFetchOptions()
options.deliveryMode = .FastFormat

PhotosHelper.getImagesFromAlbum("Album Name", options: options, completion: { (result) -> () in
    switch result {
    case .Images(let images):
        ()
    case .Image(let image):
        ()
    case .Error:
        ()
    }
})
```

To run the example project, clone the repo, and run `pod install` from the Example directory first.
Demo app needs to be run on a physical device, it requires a camera.

## Requirements

iOS 8+

## Installation

PhotosHelper is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "PhotosHelper"
```

## Author

Andrzej Filipowicz, afilipowicz.4@gmail.com

Check out our blog! [thedroidsonroids.com/blog](http://thedroidsonroids.com/blog/)

## License

PhotosHelper is available under the MIT license. See the LICENSE file for more info.
