//
//  PhotosHelper.swift
//

import Photos

/**
 Enum containing results of `getAssets(...)`, `getImages(...)` etc. calls. Depending on options can contain an array of assets or a single asset. Contains an empty error if something goes wrong.
 
 - Assets: If fetching is synchronous it will contain an array of assets. Will be called only once.
 - Asset:  If fetching is asynchronous it will contain a single asset. Can be called multiple times by the system.
 - Error:  Error fetching images.
 */
public enum AssetFetchResult<T> {
    case Assets([T])
    case Asset(T)
    case Error
}

/**
 *  A set of methods to create albums, save and retrieve images using the Photos Framework.
 */
public struct PhotosHelper {
    
    /**
     *  Define order, amount of assets and - if set - a target size. When count is set to zero all assets will be fetched. When size is not set original assets will be fetched.
     */
    public struct FetchOptions {
        var count: Int
        var newestFirst: Bool
        var size: CGSize?
        
        init() {
            self.count = 0
            self.newestFirst = true
            self.size = nil
        }
    }
    
    /// Default options to pass when fetching images. Fetches only images from the device (not from iCloud), synchronously and in best quality.
    public static var defaultImageFetchOptions: PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.version = .Original
        options.deliveryMode = .HighQualityFormat
        options.resizeMode = .None
        options.networkAccessAllowed = false
        options.synchronous = true
        
        return options
    }
    
    /**
     Create and return an album in the Photos app with a specified name. Won't overwrite if such an album already exist.
     
     - parameter named:      Name of the album.
     - parameter completion: Called in the background when an album was created.
     */
    public static func createAlbum(named: String, completion: (album: PHAssetCollection?) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            var placeholder: PHObjectPlaceholder?
            
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollectionWithTitle(named)
                placeholder = createAlbumRequest.placeholderForCreatedAssetCollection
            }) { success, error in
                var album: PHAssetCollection?
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
    public static func getAlbum(named: String, completion: (album: PHAssetCollection?) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", named)
            let collections = PHAssetCollection.fetchAssetCollectionsWithType(.Album, subtype: .Any, options: fetchOptions)
            
            if let album = collections.firstObject as? PHAssetCollection {
                completion(album: album)
            } else {
                PhotosHelper.createAlbum(named) { album in
                    completion(album: album)
                }
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
    public static func saveImage(image: UIImage, toAlbum named: String, completion: ((success: Bool, error: NSError?) -> ())? = nil) {
        PhotosHelper.getAlbum(named, completion: { album in
            guard let album = album else { completion?(success: false, error: nil); return; }
            PhotosHelper.saveImage(image, to: album, completion: completion)
        })
    }
    
    /**
     Try to save an image to a Photos album.
     - Important: The `error` parameter is only forwarded from the framework, if the image fails to save due to other reasons, even if the error is `nil` look at the `success` parameter which will be set to `false`.
     
     - parameter image:      Image to save.
     - parameter completion: Called in the background when the image was saved or in case of any error.
     */
    public static func saveImage(image: UIImage, to album: PHAssetCollection, completion: ((success: Bool, error: NSError?) -> ())? = nil) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(image)
                let placeholder = assetRequest.placeholderForCreatedAsset
                guard let _placeholder = placeholder else { completion?(success: false, error: nil); return; }
                
                let albumChangeRequest = PHAssetCollectionChangeRequest(forAssetCollection: album)
                albumChangeRequest?.addAssets([_placeholder])
            }) { success, error in
                completion?(success: success, error: error)
            }
        }
    }
    
    /**
     Try to retrieve images from a Photos album with a specified name.
     
     - parameter named:        Name of the album.
     - parameter options:      Define how the images will be fetched.
     - parameter fetchOptions: Define order and amount of images.
     - parameter completion:   Called in the background when images were retrieved or in case of any error.
     */
    public static func getImagesFromAlbum(named: String, options: PHImageRequestOptions = defaultImageFetchOptions, fetchOptions: FetchOptions = FetchOptions(), completion: (result: AssetFetchResult<UIImage>) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            let albumFetchOptions = PHFetchOptions()
            albumFetchOptions.predicate = NSPredicate(format: "(estimatedAssetCount > 0) AND (localizedTitle == %@)", named)
            let albums = PHAssetCollection.fetchAssetCollectionsWithType(.Album, subtype: .Any, options: albumFetchOptions)
            guard let album = albums.firstObject as? PHAssetCollection else { return completion(result: .Error) }
            
            PhotosHelper.getImagesFromAlbum(album, options: options, completion: completion)
        }
    }
    
    /**
     Try to retrieve images from a Photos album.
     
     - parameter options:      Define how the images will be fetched.
     - parameter fetchOptions: Define order and amount of images.
     - parameter completion:   Called in the background when images were retrieved or in case of any error.
     */
    public static func getImagesFromAlbum(album: PHAssetCollection, options: PHImageRequestOptions = defaultImageFetchOptions, fetchOptions: FetchOptions = FetchOptions(), completion: (result: AssetFetchResult<UIImage>) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            PhotosHelper.getAssetsFromAlbum(album, fetchOptions: fetchOptions, completion: { result in
                switch result {
                case .Asset: ()
                case .Error: completion(result: .Error)
                case .Assets(let assets):
                    let photos = assets.filter { $0.mediaType == .Image }
                    
                    var images = [UIImage]()
                    if options.synchronous {
                        defer {
                            completion(result: .Assets(images))
                        }
                    }

                    let imageManager = PHImageManager.defaultManager()
                    let imageRequestOptions = PHImageRequestOptions()
                    imageRequestOptions.synchronous = options.synchronous
                    imageRequestOptions.deliveryMode = options.deliveryMode

                    assets.forEach { asset in
                        imageManager.requestImageForAsset(
                            asset,
                            targetSize: fetchOptions.size ?? CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
                            contentMode: .AspectFill,
                            options: imageRequestOptions,
                            resultHandler: { image, _ in
                                guard let image = image else { return }
                                if options.synchronous {
                                    images.append(image)
                                } else {
                                    completion(result: .Asset(image))
                                }
                        })
                    }
                }
            })
        }
    }
    
    /**
     Try to retrieve assets from a Photos album.
     
     - parameter options:      Define how the assets will be fetched.
     - parameter fetchOptions: Define order and amount of assets. Size is ignored.
     - parameter completion:   Called in the background when assets were retrieved or in case of any error.
     */
    public static func getAssetsFromAlbum(album: PHAssetCollection, fetchOptions: FetchOptions = FetchOptions(), completion: (result: AssetFetchResult<PHAsset>) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            let assetsFetchOptions = PHFetchOptions()
            assetsFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !fetchOptions.newestFirst)]
            if #available(iOS 9.0, *) {
                assetsFetchOptions.fetchLimit = fetchOptions.count
            }
            
            var assets = [PHAsset]()
            defer {
                completion(result: .Assets(assets))
            }
            
            let fetchedAssets = PHAsset.fetchAssetsInAssetCollection(album, options: assetsFetchOptions)
            let range = NSRange(location: 0, length: fetchOptions.count != 0 ? fetchOptions.count - 1 : fetchedAssets.count - 1)
            
            let indexes = NSIndexSet(indexesInRange: range)
            
            fetchedAssets.enumerateObjectsAtIndexes(indexes, options: []) { asset, index, stop in
                guard let asset = asset as? PHAsset else { return completion(result: .Error) }
                assets.append(asset)
            }
        }
    }
    
    /**
     Retrieve all albums from the Photos app.
     
     - parameter completion: Called in the background when all albums were retrieved.
     */
    public static func getAlbums(completion: (albums: [PHAssetCollection]) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            
            let albums = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .AlbumRegular, options: nil)
            
            var result = [PHAssetCollection]()
            
            albums.enumerateObjectsUsingBlock { collection, index, stop in
                guard let album = collection as? PHAssetCollection else { return }
                result.append(album)
            }
            
            completion(albums: result)
        }
    }
    
    /**
     Retrieve all user created albums from the Photos app.
     
     - parameter completion: Called in the background when all albums were retrieved.
     */
    public static func getUserCreatedAlbums(completion: (albums: [PHAssetCollection]) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {

            let albums = PHCollectionList.fetchTopLevelUserCollectionsWithOptions(nil)
            
            var result = [PHAssetCollection]()
            
            albums.enumerateObjectsUsingBlock { collection, index, stop in
                guard let album = collection as? PHAssetCollection else { return }
                result.append(album)
            }
            
            completion(albums: result)
        }
    }
    
    /**
     Retrieve camera roll album the Photos app.
     
     - parameter completion: Called in the background when the album was retrieved.
     */
    public static func getCameraRollAlbum(completion: (album: PHAssetCollection?) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) {
            
            let albums = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .AlbumMyPhotoStream, options: nil)
            
            completion(album: albums.firstObject as? PHAssetCollection)
        }
    }
}
