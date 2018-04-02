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

let padding: CGFloat = 10.0

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
        captureButton.setTitle("take a picture", for: .normal)
        captureButton.sizeToFit()
        captureButton.addTarget(self, action: #selector(ViewController.takePicture(sender:)), for: .touchUpInside)
        
        captureButton.center = CGPoint(x: view.frame.midX, y: view.frame.height - captureButton.frame.midY - padding)
        
        view.addSubview(captureButton)
    }

    func setupCamera() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        setDeviceInput()
        
        if captureSession.canSetSessionPreset(AVCaptureSession.Preset.high) {
            captureSession.sessionPreset = AVCaptureSession.Preset.high
        }
        
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        
        captureLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        captureLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        captureLayer?.frame = view.bounds
        guard let captureLayer = captureLayer else { return }
        view.layer.addSublayer(captureLayer)
        
        captureSession.commitConfiguration()
        captureSession.startRunning()
    }
    
    private func setDeviceInput(back: Bool = true) {
        guard let captureSession = captureSession else { return }
        
        if let input = captureSession.inputs.first {
            captureSession.removeInput(input)
        }
        
        let device = AVCaptureDevice.devices(for: AVMediaType.video)
            .filter {$0.position == (back ? .back : .front)}
            .first ?? AVCaptureDevice.default(for: AVMediaType.video)
        
        guard let input = try? AVCaptureDeviceInput(device: device!) else { return }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
    }
    
    
    @objc func takePicture(sender: AnyObject) {
        let connection = output.connection(with: AVMediaType.video)
        output.captureStillImageAsynchronously(from: connection!) { [weak self] buffer, error in
            guard let `self` = self, error == nil else { return }
            let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer!)!
            guard let image = UIImage(data: imageData) else { return }
            
            PhotosHelper.saveImage(image, toAlbum: "Example Album") { success, _ in
                guard success else { return }
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Photo taken", message: "Open Photos.app to see that an album with your photo was created.", preferredStyle: .alert)
                    let action = UIAlertAction(title: "Ok", style: .default, handler: nil)
                    alert.addAction(action)
                    
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
}

