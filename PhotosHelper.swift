//
//  PhotosHelper.swift
//

import Photos

private let PhotoAlbumTitle = "Example Album"

/**
 *  A set of methods to create albums, save and retrieve images using the Photos Framework.
 */
public struct PhotosHelper {
    /**
     Options to feed to the **PHImageManager** and the images request itself.
     - Important: Depending on the values set to `synchronous` and `deliveryMode` there may be default values which will override the user specified input. Default values are set to return synchronously only the best quality image.
     - SeeAlso: For more information refer to the **`PHImageRequestOptions`** documentation.
     */
    public struct ImageFetchOptions {
        var newestFirst: Bool
        var size: CGSize?
        var contentMode: PHImageContentMode
        var synchronous: Bool
        var deliveryMode: PHImageRequestOptionsDeliveryMode
        
        init() {
            newestFirst = true
            size = nil
            contentMode = .AspectFill
            synchronous = true
            deliveryMode = .HighQualityFormat
        }
    }
    
    /**
     Enum containing results of `getImagesFromAlbum` call. Depending on options can contain an array of images or a single image. Contains an empty error if something goes wrong.
     
     - Images: If fetching is synchronous it will contain an array of images. Will be called only once.
     - Image:  If fetching is asynchronous it will contain a single image. Can be called multiple times by the system.
     - Error:  Error fetching images.
     */
    public enum ImageFetchResult {
        case Images([UIImage])
        case Image(UIImage)
        case Error
    }
    
    /**
     Create and return an album in the Photos app with a specified name. Won't overwrite if such an album already exist.
     
     - parameter named:      Name of the album.
     - parameter completion: Called in the background when an album was created.
     */
    public static func createAlbum(named: String = PhotoAlbumTitle, completion: (album: PHAssetCollection?) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { () -> Void in
            var placeholder: PHObjectPlaceholder? = nil
            
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
                let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollectionWithTitle(named)
                placeholder = createAlbumRequest.placeholderForCreatedAssetCollection
            }) { (success, error) -> Void in
                var album: PHAssetCollection? = nil
                if success {
                    let collectionFetchResult = PHAssetCollection.fetchAssetCollectionsWithLocalIdentifiers([placeholder?.localIdentifier ?? ""], options: nil)
                    album = collectionFetchResult.firstObject as? PHAssetCollection
                }
                
                completion(album: album)
            }
        }
    }
    
    /**
     Retrieve an album from the Photos app with a specified name. If no such album exists, creates and returns a new one.
     
     - parameter named:      Name of the album.
     - parameter completion: Called in the background when an album was retrieved.
     */
    public static func getAlbum(named: String = PhotoAlbumTitle, completion: (album: PHAssetCollection?) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { () -> Void in
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", named)
            let collections: PHFetchResult = PHAssetCollection.fetchAssetCollectionsWithType(.Album, subtype: .Any, options: fetchOptions)
            
            if let album = collections.firstObject as? PHAssetCollection {
                completion(album: album)
            } else {
                PhotosHelper.createAlbum(named, completion: { (album) -> () in
                    completion(album: album)
                })
            }
        }
    }
    
    /**
     Try to save an image to a Photos album with a specified name. If no such album exists, creates a new one. 
     - Important: The `error` parameter is only forwarded from the framework, if the image fails to save due to other reasons, even if the error is `nil` look at the `success` parameter which will be set to `false`.
     
     - parameter image:      Image to save.
     - parameter named:      Name of the album.
     - parameter completion: Called in the background when the image was saved or in case of any error.
     */
    public static func saveImage(image: UIImage, toAlbum named: String = PhotoAlbumTitle, completion: ((success: Bool, error: NSError?) -> ())? = nil) {
        PhotosHelper.getAlbum(named, completion: { (album) -> () in
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
                let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(image)
                let placeholder = assetRequest.placeholderForCreatedAsset
                guard let _placeholder = placeholder else { completion?(success: false, error: nil); return; }
                guard let album = album else { completion?(success: false, error: nil); return; }
                
                let albumChangeRequest = PHAssetCollectionChangeRequest(forAssetCollection: album)
                albumChangeRequest?.addAssets([_placeholder])
            }) { (success, error) -> Void in
                completion?(success: success, error: error)
            }
        })
    }
    
    /**
     Try to retrieve images from a Photos album with a specified name.
     
     - parameter named:      Name of the album.
     - parameter options:    Define how the images will be fetched.
     - parameter completion: Called in the background when images were retrieved or in case of any error.
     */
    public static func getImagesFromAlbum(named: String = PhotoAlbumTitle, options: ImageFetchOptions = ImageFetchOptions(), completion: (result: ImageFetchResult) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { () -> Void in
            let albumFetchOptions = PHFetchOptions()
            albumFetchOptions.predicate = NSPredicate(format: "(estimatedAssetCount > 0) AND (localizedTitle == %@)", named)
            let albums = PHAssetCollection.fetchAssetCollectionsWithType(.Album, subtype: .Any, options: albumFetchOptions)
            guard let album = albums.firstObject as? PHAssetCollection else { return completion(result: .Error) }
            
            let photosFetchOptions = PHFetchOptions()
            photosFetchOptions.predicate = NSPredicate(format: "mediaType = %i", PHAssetMediaType.Image.rawValue)
            photosFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !options.newestFirst)]
            
            var images = [UIImage]()
            if options.synchronous {
                defer {
                    completion(result: .Images(images))
                }
            }
            
            let imageManager = PHImageManager.defaultManager()
            let imageRequestOptions = PHImageRequestOptions()
            imageRequestOptions.synchronous = options.synchronous
            imageRequestOptions.deliveryMode = options.deliveryMode
            
            let photos = PHAsset.fetchAssetsInAssetCollection(album, options: photosFetchOptions)
            photos.enumerateObjectsUsingBlock { (asset, index, stop) -> Void in
                guard let asset = asset as? PHAsset else { return completion(result: .Error) }
                imageManager.requestImageForAsset(
                    asset,
                    targetSize: options.size ?? CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
                    contentMode: .AspectFill,
                    options: imageRequestOptions,
                    resultHandler: { (image, _) -> Void in
                        guard let image = image else { return }
                        if options.synchronous {
                            images.append(image)
                        } else {
                            completion(result: .Image(image))
                        }
                })
            }
        }
    }
}
