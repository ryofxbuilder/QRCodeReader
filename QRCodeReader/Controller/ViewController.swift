//
//  ViewController.swift
//  QRCodeReader
//
//  Created by Ryosuke Akanuma on 2016/12/11.
//  Copyright © 2016年 jp.co.numa. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBOutlet private weak var captureView: UIView!
    var captureSession = AVCaptureSession()
    var captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
    lazy var capturePreviewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        return layer!
    }()
    
    private var captureInput: AVCaptureInput? = nil
    private lazy var captureOutput: AVCaptureMetadataOutput = {
        let output = AVCaptureMetadataOutput()
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        return output
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        setupBarcodeCapture()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        capturePreviewLayer.frame = self.captureView?.bounds ?? CGRect()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - private
    private func setupBarcodeCapture() {
        do {
            captureInput = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(captureInput)
            captureSession.addOutput(captureOutput)
            captureOutput.metadataObjectTypes = captureOutput.availableMetadataObjectTypes
            capturePreviewLayer.frame = self.captureView?.bounds ?? CGRect(x: 0, y: 0, width: 0, height: 0
            )
            capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            captureView?.layer.addSublayer(capturePreviewLayer)
            captureSession.startRunning()
        } catch let error as NSError {
            print(error)
        }
    }
    
    func convartISBN(value: String) -> String? {
        let v = NSString(string: value).longLongValue
        let prefix: Int64 = Int64(v / 10000000000)
        guard prefix == 978 || prefix == 979 else { return nil }
        let isbn9: Int64 = (v % 10000000000) / 10
        var sum: Int64 = 0
        var tmpISBN = isbn9
        
        var i = 10
        while i > 0 && tmpISBN > 0 {
            let divisor: Int64 = Int64(pow(10, Double(i - 2)))
            sum += (tmpISBN / divisor) * Int64(i)
            tmpISBN %= divisor
            i -= 1
        }
        
        let checkdigit = 11 - (sum % 11)
        return String(format: "%lld%@", isbn9, (checkdigit == 10) ? "X" : String(format: "%lld", checkdigit % 11))
    }
}

extension ViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        self.captureSession.stopRunning()
        guard let objects = metadataObjects as? [AVMetadataObject] else { return }
        var detectionString: String? = nil
        let barcodeTypes = [AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeEAN13Code]
        for metadataObject in objects {
            loop: for type in barcodeTypes {
                guard metadataObject.type == type else { continue }
                guard self.capturePreviewLayer.transformedMetadataObject(for: metadataObject) is AVMetadataMachineReadableCodeObject else { continue }
                if let object = metadataObject as? AVMetadataMachineReadableCodeObject {
                    detectionString = object.stringValue
                    break loop
                }
            }
            var text = ""
            guard let value = detectionString else { continue }
            text += "読み込んだ値:\t\(value)"
            text += "\n"
            guard let isbn = convartISBN(value: value) else { continue }
            text += "ISBN:\t\(isbn)"
            let URLString = String(format: "http://amazon.co.jp/dp/%@", isbn)
            guard let URL = NSURL(string: URLString) else { continue }
            print(URL)
            if UIApplication.shared.canOpenURL(URL as URL) {
                UIApplication.shared.open(URL as URL, options: [:], completionHandler: nil)
            }
        }
        self.captureSession.startRunning()
    }
}

