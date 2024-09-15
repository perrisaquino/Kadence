//
//  ViewController.swift
//  Kadence Test
//
//  Created by Perris Aquino on 9/10/24.
//

import UIKit
import AVFoundation
import Photos
import MobileCoreServices

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate, UIDocumentPickerDelegate {
    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var movieOutput = AVCaptureMovieFileOutput()
    var isRecording = false
    var audioPlayer: AVAudioPlayer?  // For playing selected music file
    var selectedMusicURL: URL?       // The music file chosen by the user
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize the capture session
        captureSession = AVCaptureSession()
        
        // Get the default camera device
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            print("Failed to get the camera device")
            return
        }
        
        do {
            // Set up the input from the camera
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession?.addInput(input)
            
            // Add the movie output for recording
            if captureSession!.canAddOutput(movieOutput) {
                captureSession?.addOutput(movieOutput)
            }
            
            // Set up the video preview layer to display the camera feed
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = .resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer!)
            
            // Add the record button
            let recordButton = UIButton(frame: CGRect(x: 150, y: view.frame.height - 100, width: 100, height: 50))
            recordButton.backgroundColor = .red
            recordButton.setTitle("Record", for: .normal)
            recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
            view.addSubview(recordButton)
            
            // Add the song selection button
            let selectSongButton = UIButton(frame: CGRect(x: 50, y: view.frame.height - 150, width: 120, height: 50))
            selectSongButton.backgroundColor = .blue
            selectSongButton.setTitle("Select Song", for: .normal)
            selectSongButton.addTarget(self, action: #selector(selectSongTapped), for: .touchUpInside)
            view.addSubview(selectSongButton)
            
            // Add a label to display the selected song name
            let songLabel = UILabel(frame: CGRect(x: 50, y: view.frame.height - 200, width: 300, height: 50))
            songLabel.text = "No song selected"
            songLabel.tag = 101 // We'll use this tag to reference it later
            view.addSubview(songLabel)
            
            // Start the capture session
            captureSession?.startRunning()
            
        } catch {
            print("Error: \(error)")
        }
    }
    
    @objc func recordButtonTapped(_ sender: UIButton) {
        if isRecording {
            // Stop recording
            movieOutput.stopRecording()
            isRecording = false
            sender.setTitle("Record", for: .normal)
            audioPlayer?.stop()  // Stop the music when recording stops
        } else {
            // Start recording with a unique file name
            let outputDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let timestamp = Int(Date().timeIntervalSince1970) // Unique file name using timestamp
            let fileURL = outputDirectory.appendingPathComponent("output_\(timestamp).mov")
            
            movieOutput.startRecording(to: fileURL, recordingDelegate: self)
            isRecording = true
            sender.setTitle("Stop", for: .normal)
            
            // Play the selected song if available
            if let selectedMusicURL = selectedMusicURL {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: selectedMusicURL)
                    audioPlayer?.play()
                } catch {
                    print("Error playing audio: \(error)")
                }
            }
        }
    }
    
    @objc func selectSongTapped(_ sender: UIButton) {
        // Open document picker to select an audio file
        let documentPicker = UIDocumentPickerViewController(documentTypes: [kUTTypeAudio as String], in: .import)
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    // Document picker delegate function to handle selected song
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            selectedMusicURL = url
            if let songLabel = view.viewWithTag(101) as? UILabel {
                songLabel.text = "Selected: \(url.lastPathComponent)"
            }
        }
    }
    
    func mergeVideoAndAudio(videoURL: URL, audioURL: URL, outputURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        // Create an AVMutableComposition to hold video and audio
        let mixComposition = AVMutableComposition()
        
        // Add video track
        let videoAsset = AVURLAsset(url: videoURL)
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            completion(false, NSError(domain: "Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video track is missing"]))
            return
        }
        
        let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        do {
            try videoCompositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: videoTrack, at: .zero)
        } catch {
            completion(false, error)
            return
        }
        
        // Add audio track
        let audioAsset = AVURLAsset(url: audioURL)
        guard let audioTrack = audioAsset.tracks(withMediaType:   .audio).first else {
            completion(false, NSError(domain: "Error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio track is missing"]))
            return
        }
        
        let audioCompositionTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        do {
            try audioCompositionTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: audioTrack, at: .zero)
        } catch {
            completion(false, error)
            return
        }
        
        // Export the merged video and audio
        let assetExport = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        assetExport?.outputURL = outputURL
        assetExport?.outputFileType = .mov
        assetExport?.shouldOptimizeForNetworkUse = true
        
        assetExport?.exportAsynchronously(completionHandler: {
            switch assetExport?.status {
            case .completed:
                print("Export completed")
                completion(true, nil)
            case .failed:
                print("Export failed: \(String(describing: assetExport?.error))")
                completion(false, assetExport?.error)
            case .cancelled:
                print("Export canceled")
                completion(false, nil)
            default:
                break
            }
        })
    }
    
    // Delegate function to handle what happens when recording finishes
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Error recording video: \(error)")
        } else {
            print("Video recorded successfully: \(outputFileURL)")
            
            // Merge video with selected audio
            if let selectedMusicURL = selectedMusicURL {
                let outputDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let mergedFileURL = outputDirectory.appendingPathComponent("merged_output_\(Int(Date().timeIntervalSince1970)).mov")
                
                // Call the merge function
                mergeVideoAndAudio(videoURL: outputFileURL, audioURL: selectedMusicURL, outputURL: mergedFileURL) { success, error in
                    if success {
                        print("Merged video and audio successfully: \(mergedFileURL)")
                        
                        // Save the merged video to the Photos library
                        PHPhotoLibrary.requestAuthorization { status in
                            if status == .authorized {
                                PHPhotoLibrary.shared().performChanges({
                                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: mergedFileURL)
                                }) { success, error in
                                    if success {
                                        print("Merged video saved to Photos")
                                    } else if let error = error {
                                        print("Error saving merged video to Photos: \(error)")
                                    }
                                }
                            } else {
                                print("Permission to access Photos was denied.")
                            }
                        }
                    } else if let error = error {
                        print("Error merging video and audio: \(error)")
                    }
                }
            } else {
                print("No music selected to merge with video.")
            }
        }
    }
}

