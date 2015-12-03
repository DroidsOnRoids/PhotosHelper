//
//  ViewController.swift
//  PhotosHelper
//
//  Created by Andrzej Filipowicz on 12/03/2015.
//  Copyright (c) 2015 Andrzej Filipowicz. All rights reserved.
//

import UIKit
import AVFoundation
import PhotosHelper

let Padding: CGFloat = 10

class ViewController: UIViewController {

    var captureSession: AVCaptureSession?
    var captureLayer: AVCaptureVideoPreviewLayer?
    let output = AVCaptureStillImageOutput()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCamera()
        setupUI()
    }

    func setupUI() {
        view.clipsToBounds = true
        
        let captureButton = UIButton()
        captureButton.setTitle("take a picture", forState: .Normal)
        captureButton.sizeToFit()
        captureButton.addTarget(self, action: "takePicture:", forControlEvents: .TouchUpInside)
        
        captureButton.center = CGPoint(x: view.frame.width / 2, y: view.frame.height - captureButton.frame.height / 2 - Padding)
        
        view.addSubview(captureButton)
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        setDeviceInput()
        
        if captureSession.canSetSessionPreset(AVCaptureSessionPresetHigh) {
            captureSession.sessionPreset = AVCaptureSessionPresetHigh
        }
        
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        
        captureLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        captureLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        captureLayer?.frame = view.bounds
        guard let captureLayer = captureLayer else { return }
        view.layer.addSublayer(captureLayer)
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
    
    private func setDeviceInput(back: Bool = true) {
        guard let captureSession = captureSession else { return }
        
        if let input = captureSession.inputs.first as? AVCaptureInput {
            captureSession.removeInput(input)
        }
        
        let device = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).filter({$0.position == (back ? .Back : .Front)}).first as? AVCaptureDevice ??
            AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch _ {
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
    }
    
    
    func takePicture(sender: AnyObject) {
        let connection = output.connectionWithMediaType(AVMediaTypeVideo)
        output.captureStillImageAsynchronouslyFromConnection(connection) { (buffer, error) -> Void in
            if error == nil {
                let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer)
                guard let image = UIImage(data: imageData) else { return }
                
                PhotosHelper.saveImage(image)
            }
        }
    }
}

