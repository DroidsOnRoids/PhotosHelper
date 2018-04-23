//
//  PhotosHelper.swift
//

import Photos

/**
 Enum containing results of `getAssets(...)`, `getImages(...)` etc. calls. Depending on options can contain an array of assets or a single asset. Contains an empty error if something goes wrong.
 
 - Assets: Contains an array of assets. Will be called only once.
 - Asset:  Contains a single asset. If options.synchronous is set to `false` can be called multiple times by the system.
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
        public var count: Int
        public var newestFirst: Bool
        public var size: CGSize?
        
        public init() {
            self.count = 0
            self.newestFirst = true
            self.size = nil
        }
    }
    
    /// Default options to pass when fetching images. Fetches only images from the device (not from iCloud), synchronously and in best quality.
    public static var defaultImageFetchOptions: PHImageRequestOptions {
        let options = PHImageRequestOptions()
        options.version = .original
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = false
        options.isSynchronous = true
        
        return options
    }
    
    /**
     Create and return an album in the Photos app with a specified name. Won't overwrite if such an album already exist.
     
     - parameter named:      Name of the album.
     - parameter completion: Called in the background when an album was created.
     */
    public static func createAlbum(named: String, completion: @escaping (_ album: PHAssetCollection?) -> ()) {
        DispatchQueue.global(qos: .background).async {
            var placeholder: PHObjectPlaceholder?
            
            PHPhotoLibrary.shared().performChanges({
                let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: named)
                placeholder = createAlbumRequest.placeholderForCreatedAssetCollection
            }) { success, error in
                var album: PHAssetCollection?
                if success {
                    let collectionFetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder?.localIdentifier ?? ""], options: nil)
                    album = collectionFetchResult.firstObject
                }
                
                completion(album)
            }
        }
    }
    
    /**
     Retrieve an album from the Photos app with a specified name. If no such album exists, creates and returns a new one.
     
     - parameter named:      Name of the album.
     - parameter completion: Called in the background when an album was retrieved.
     */
    public static func getAlbum(named: String, completion: @escaping (_ album: PHAssetCollection?) -> ()) {
        DispatchQueue.global(qos: .background).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", named)
            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            
            if let album = collections.firstObject {
                completion(album)
            } else {
                PhotosHelper.createAlbum(named: named) { album in
                    completion(album)
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
    public static func saveImage(_ image: UIImage, toAlbum named: String, completion: ((_ success: Bool, _ error: Error?) -> ())? = nil) {
        PhotosHelper.getAlbum(named: named, completion: { album in
            guard let album = album else { completion?(false, nil); return; }
            PhotosHelper.saveImage(image, to: album, completion: completion)
        })
    }
    
    /**
     Try to save an image to a Photos album.
     - Important: The `error` parameter is only forwarded from the framework, if the image fails to save due to other reasons, even if the error is `nil` look at the `success` parameter which will be set to `false`.
     
     - parameter image:      Image to save.
     - parameter completion: Called in the background when the image was saved or in case of any error.
     */
    public static func saveImage(_ image: UIImage, to album: PHAssetCollection, completion: ((_ success: Bool, _ error: Error?) -> ())? = nil) {
        DispatchQueue.global(qos: .background).async {
            PHPhotoLibrary.shared().performChanges({
                let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                let placeholder = assetRequest.placeholderForCreatedAsset
                guard let _placeholder = placeholder else { completion?(false, nil); return; }
                
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                albumChangeRequest?.addAssets(NSArray(object: _placeholder))
            }) { success, error in
                completion?(success, error)
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
    public static func getImagesFromAlbum(_ named: String, options: PHImageRequestOptions = defaultImageFetchOptions, fetchOptions: FetchOptions = FetchOptions(), completion: @escaping (_ result: AssetFetchResult<UIImage>) -> ()) {
        DispatchQueue.global(qos: .background).async {
            let albumFetchOptions = PHFetchOptions()
            albumFetchOptions.predicate = NSPredicate(format: "(estimatedAssetCount > 0) AND (localizedTitle == %@)", named)
            let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: albumFetchOptions)
            guard let album = albums.firstObject else { return completion(.Error) }
            
            PhotosHelper.getImagesFromAlbum(album, options: options, completion: completion)
        }
    }
    
    /**
     Try to retrieve images from a Photos album.
     
     - parameter options:      Define how the images will be fetched.
     - parameter fetchOptions: Define order and amount of images.
     - parameter completion:   Called in the background when images were retrieved or in case of any error.
     */
    public static func getImagesFromAlbum(_ album: PHAssetCollection, options: PHImageRequestOptions = defaultImageFetchOptions, fetchOptions: FetchOptions = FetchOptions(), completion: @escaping (_ result: AssetFetchResult<UIImage>) -> ()) {
        DispatchQueue.global(qos: .background).async {
            PhotosHelper.getAssetsFromAlbum(album, fetchOptions: fetchOptions, completion: { result in
                switch result {
                case .Asset: ()
                case .Error: completion(.Error)
                case .Assets(let assets):
                    let imageManager = PHImageManager.default()
                    
                    assets.forEach { asset in
                        imageManager.requestImage(
                            for: asset,
                            targetSize: fetchOptions.size ?? CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
                            contentMode: .aspectFill,
                            options: options,
                            resultHandler: { image, _ in
                                guard let image = image else { return }
                                completion(.Asset(image))
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
    public static func getAssetsFromAlbum(_ album: PHAssetCollection, fetchOptions: FetchOptions = FetchOptions(), completion: @escaping (_ result: AssetFetchResult<PHAsset>) -> ()) {
        DispatchQueue.global(qos: .background).async {
            let assetsFetchOptions = PHFetchOptions()
            assetsFetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !fetchOptions.newestFirst)]
            
            var assets = [PHAsset]()
            
            let fetchedAssets = PHAsset.fetchAssets(in: album, options: assetsFetchOptions)
            
            let rangeLength = fetchOptions.count != 0 ? min(fetchedAssets.count, fetchOptions.count) : fetchedAssets.count
            let range = NSMakeRange(0, rangeLength)
            let indexSet = NSIndexSet(indexesIn: range) as IndexSet
            
            fetchedAssets.enumerateObjects(at: indexSet, options: []) { asset, index, stop in
                assets.append(asset)
            }
            
            completion(.Assets(assets))
        }
    }
    
    /**
     Retrieve all albums from the Photos app.
     
     - parameter completion: Called in the background when all albums were retrieved.
     */
    public static func getAlbums(completion: @escaping (_ albums: [PHAssetCollection]) -> ()) {
        DispatchQueue.global(qos: .background).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
            
            let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: fetchOptions)
            
            var result = Set<PHAssetCollection>()
            
            [albums, smartAlbums].forEach {
                $0.enumerateObjects { collection, index, stop in
                    result.insert(collection)
                }
            }
            
            completion(Array<PHAssetCollection>(result))
        }
    }
    
    /**
     Retrieve all user created albums from the Photos app.
     
     - parameter completion: Called in the background when all albums were retrieved.
     */
    public static func getUserCreatedAlbums(completion: @escaping (_ albums: [PHAssetCollection]) -> ()) {
        DispatchQueue.global(qos: .background).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
            
            let albums = PHCollectionList.fetchTopLevelUserCollections(with: fetchOptions)
            
            var result = [PHAssetCollection]()
            
            albums.enumerateObjects { collection, index, stop in
                guard let album = collection as? PHAssetCollection else { return }
                result.append(album)
            }
            
            completion(result)
        }
    }
    
    /**
     Retrieve camera roll album the Photos app.
     
     - parameter completion: Called in the background when the album was retrieved.
     */
    public static func getCameraRollAlbum(completion: @escaping (_ album: PHAssetCollection?) -> ()) {
        DispatchQueue.global(qos: .background).async {
            let albums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .albumMyPhotoStream, options: nil)
            
            completion(albums.firstObject)
        }
    }
}
