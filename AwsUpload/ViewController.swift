//
//  ViewController.swift
//  AwsUpload
//
//  Created by Sarah Griffis on 3/5/16.
//  Copyright © 2016 Sarah Griffis. All rights reserved.
//

import UIKit
import Alamofire
import AWSS3
import CTAssetsPickerController
//import PhotosUI

public class ViewController: UIViewController, CTAssetsPickerControllerDelegate {
    
    var uploadRequests = Array<AWSS3TransferManagerUploadRequest?>()
    var uploadFileURLs = Array<NSURL?>()

    override public func viewDidLoad() {
        super.viewDidLoad()
        
        let error = NSErrorPointer()
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(
                NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("upload"),
                withIntermediateDirectories: true,
                attributes: nil)
        } catch let error1 as NSError {
            error.memory = error1
            print("Creating 'upload' directory failed. Error: \(error)")
        }
        
        setUpNavigationItems()
    }
}

//MARK: NavigationMethods
extension ViewController {

    func selectPictures(){
        let imagePickerController = CTAssetsPickerController()
        imagePickerController.delegate = self
//        imagePickerController.maximumImagesCount = 20
//        imagePickerController.imagePickerDelegate = self
        
        self.presentViewController(
            imagePickerController,
            animated: true) { () -> Void in }
    }
    
    func cancelAllUploads(){}
    
    func showAlertController() {
        let alertController = UIAlertController(
            title: "Available Actions",
            message: "Choose your action.",
            preferredStyle: .ActionSheet)
        
        let selectPictureAction = UIAlertAction(
            title: "Select Pictures",
            style: .Default) { (action) -> Void in
                self.selectPictures()
        }
        alertController.addAction(selectPictureAction)
        
        let cancelAllUploadsAction = UIAlertAction(
            title: "Cancel All Uploads",
            style: .Default) { (action) -> Void in
                self.cancelAllUploads()
        }
        alertController.addAction(cancelAllUploadsAction)
        
        let cancelAction = UIAlertAction(
            title: "Cancel",
            style: .Cancel) { (action) -> Void in }
        alertController.addAction(cancelAction)
        
        self.presentViewController(
            alertController,
            animated: true) { () -> Void in }
    }
}

//MARK: setup Navigation Bar
extension ViewController {

    func setUpNavigationItems() -> Void {
        let uploadButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: self, action: "showAlertController")
        
        self.navigationItem.rightBarButtonItem = uploadButton
    }
}


//MARK: CTAssetsPickerControllerDelegate
extension ViewController {
    
    public func assetsPickerController(picker: CTAssetsPickerController!, didFinishPickingAssets assets: [AnyObject]!){
        
        self.dismissViewControllerAnimated(true, completion: nil)
        
        let manager = PHImageManager.defaultManager()
        
        for (_, pHObject) in assets.enumerate() {
            if let pHObject = pHObject as? PHAsset {
                if pHObject.mediaType == PHAssetMediaType.Image {
                    
                    let fileName = NSProcessInfo.processInfo().globallyUniqueString.stringByAppendingString(".png")
                    let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).URLByAppendingPathComponent("upload").URLByAppendingPathComponent(fileName)
                    let filePath = fileURL.path!
                    
                    manager.requestImageDataForAsset(pHObject, options: nil, resultHandler: { (imageData: NSData?, dataUTI: String?, orientation: UIImageOrientation, info: [NSObject : AnyObject]?) -> Void in
                        
 
                        
                        //let imageData = UIImagePNGRepresentation(image)
                        if imageData!.writeToFile(filePath, atomically: true) {
                            print("written")
                        }
                        
                        let uploadRequest = AWSS3TransferManagerUploadRequest()
                        uploadRequest.body = fileURL
                        uploadRequest.key = fileName
                        uploadRequest.bucket = S3BucketName
                        
                        self.uploadRequests.append(uploadRequest)
                        self.uploadFileURLs.append(nil)
                        self.upload(uploadRequest)
                        
                        
                    })
                }
            }
        }
        print(self.uploadFileURLs.count)
    }
}

//MARK: file uploads
extension ViewController {
    public func upload(uploadRequest: AWSS3TransferManagerUploadRequest) {
        let transferManager = AWSS3TransferManager.defaultS3TransferManager()
        
        transferManager.upload(uploadRequest).continueWithBlock { (task) -> AnyObject! in
            if let error = task.error {
                if error.domain == AWSS3TransferManagerErrorDomain as String {
                    if let errorCode = AWSS3TransferManagerErrorType(rawValue: error.code) {
                        switch (errorCode) {
                        case .Cancelled, .Paused:
                            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                                //self.collectionView.reloadData()
                            })
                            break;
                            
                        default:
                            print("upload() failed: [\(error)]")
                            break;
                        }
                    } else {
                        print("upload() failed: [\(error)]")
                    }
                } else {
                    print("upload() failed: [\(error)]")
                }
            }
            
            if let exception = task.exception {
                print("upload() failed: [\(exception)]")
            }
            
            if task.result != nil {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    if let index = self.indexOfUploadRequest(self.uploadRequests, uploadRequest: uploadRequest) {
                        self.uploadRequests[index] = nil
                        self.uploadFileURLs[index] = uploadRequest.body
                        
                        let indexPath = NSIndexPath(forRow: index, inSection: 0)
                        //self.collectionView.reloadItemsAtIndexPaths([indexPath])
                    }
                })
            }
            return nil
        }
    }
    
    func indexOfUploadRequest(array: Array<AWSS3TransferManagerUploadRequest?>, uploadRequest: AWSS3TransferManagerUploadRequest?) -> Int? {
        for (index, object) in array.enumerate() {
            if object == uploadRequest {
                return index
            }
        }
        return nil
    }
}


