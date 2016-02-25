//
//  AudioPlayerViewController.swift
//  VoiceRecorderSwift
//
//  Created by Дмитрий Буканович on 05.09.15.
//  Copyright (c) 2015 Дмитрий Буканович. All rights reserved.
//

import UIKit
import AVFoundation
import TLSphinx


class AudioPlayerViewController: UIViewController {
    
    @IBOutlet weak var audioSlider : UISlider!
    @IBOutlet weak var audioLengthLabel : UILabel!
    @IBOutlet weak var audioRemainLengthLabel : UILabel!
    @IBOutlet weak var audioNameLabel : UILabel!
    @IBOutlet weak var playPauseBtn : UIButton!
    
    lazy var directoryURL : NSURL = {
        let dirPaths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory,.UserDomainMask, true)
        let docsDir = dirPaths[0] 
        let directiryURL = NSURL(fileURLWithPath: docsDir)
        return directiryURL
        }()
    
    
    var audioPlayer : AVAudioPlayer!
    
    var audioList = AudioList.sharedInstance
    var currentIndex : Int = 0
    
    var timer : NSTimer!
    
    var previousPlayingTime : Double = 0
    var previousPlaying = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        self.setupAudioPlayer()
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "beginInterruption:", name: AVAudioSessionInterruptionNotification, object: nil)
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayback)
        } catch let error as NSError {
            dbprint("Error set category audio session: \(error.localizedDescription)")
        }
        
        do {
            try audioSession.setActive(true)
        } catch let error as NSError {
            dbprint("Error activate audio session: \(error.localizedDescription)")
        }

    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
        
        
        
    }
    
    // MARK: - Audio Player Lifecycle
    
    func setupAudioPlayer() {
        let audioItem = self.audioList.items[currentIndex] 
        self.audioNameLabel.text = audioItem.title
        
        audioRemainLengthLabel.text = "-\(audioItem.length)"
        
        
        let audioFileURL = self.directoryURL.URLByAppendingPathComponent("\(audioItem.title).caf")
    
        let index = audioFileURL.absoluteString.startIndex.advancedBy(7)
        let decodeFileName = audioFileURL.absoluteString.substringFromIndex(index)
        testSpeechFromFile(decodeFileName)
        
        self.timer?.invalidate()
        do {
            try self.audioPlayer = AVAudioPlayer(contentsOfURL: audioFileURL)
        } catch {
            dbprint("we have some errors in setup player")
        }
        self.audioPlayer.delegate = self
        self.audioPlayer.volume = 1.0
        self.audioPlayer.prepareToPlay()
        
        audioSlider.minimumValue = 0.0
        audioSlider.maximumValue = Float(self.audioPlayer.duration)
        audioSlider.continuous = true
        audioSlider.value = 0.0
    }

    func getModelPath() -> String? {
        
        let path:String? = NSBundle(forClass: AudioPlayerViewController.self).pathForResource("en-us", ofType: nil)
        
        return path

    }
    
    
    func playPausePlayer() {
        
        if self.audioPlayer.playing {
            playPauseBtn.setTitle("Play Audio", forState: UIControlState.Normal)
            self.audioPlayer.pause()
            self.timer?.invalidate()
            previousPlaying = false
        } else {
            self.audioPlayer.play()
            playPauseBtn.setTitle("Pause Audio", forState: UIControlState.Normal)
            previousPlaying = true
            self.timer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: "runUIIteraction", userInfo: nil, repeats: true)
        }

    }
    
    
    func runUIIteraction() {
        
        
        self.audioSlider.value = Float(self.audioPlayer.currentTime)
        
        self.setTimeLabelsValues()
        
    }
    
    // MARK: - UI Labels
    
    func setTimeLabelsValues() {
        
        let currentTime = self.audioPlayer.currentTime
        let duration = self.audioPlayer.duration
        
        audioLengthLabel.text = convertCurrentTimeToString(currentTime, duration: duration, current: true)
        audioRemainLengthLabel.text = convertCurrentTimeToString(currentTime, duration: duration, current: false)
        
    }
    
    func convertCurrentTimeToString(currentTime : Double, duration : Double, current : Bool) -> String {
        
        let secondsCount =  current ? Int(currentTime) : Int(duration - currentTime)
        
        let sec = secondsCount % secondsInMinute
        let minute = (secondsCount % (secondsInMinute * secondsInMinute)) / secondsInMinute
        let hour = secondsCount / (secondsInMinute * secondsInMinute)
        let minus = current ? "" : "-"
        
        return NSString(format: "%@%02d:%02d:%02d", minus, hour, minute, sec) as String
    }
    
    
    // MARK: - Actions

    @IBAction func audioSliderValueChanged(sender: AnyObject) {
        
        let value = Double((sender as! UISlider).value)
        self.audioPlayer.currentTime = value
        self.setTimeLabelsValues()
        
    }
    
    
    
    @IBAction func backAction(sender: AnyObject) {
        
        self.stopAudioAction(NSNull)
        self.navigationController?.popViewControllerAnimated(true)
        
    }
    
    @IBAction func playAudioAction(sender: AnyObject) {
        
        self.playPausePlayer()
        
    }
    
    @IBAction func stopAudioAction(sender: AnyObject) {
        
        playPauseBtn.setTitle("Play Audio", forState: UIControlState.Normal)
        self.audioPlayer?.stop()
        self.audioPlayer?.currentTime = 0
        self.timer?.invalidate()
        previousPlaying = false
        self.runUIIteraction()
        
    }
    
    @IBAction func nextAudioAction(sender: AnyObject) {
        self.currentIndex++
        if currentIndex >= self.audioList.items.count {
            currentIndex = 0
        }
        self.setupAudioPlayer()
        self.playPausePlayer()
    }
    
    @IBAction func RecordAgainAction(sender: AnyObject) {
        
        self.stopAudioAction(NSNull)
        let audioSession = AVAudioSession.sharedInstance()

        try! audioSession.setActive(false)


        
    }
    
    
    // MARK: - AudioSessionInterruptions
    
    func beginInterruption(notification : NSNotification) {
        let which : AnyObject? = notification.userInfo?[AVAudioSessionInterruptionTypeKey]
        if which != nil {
            if let began = which! as? UInt {
                if began == 0 {
                    dbprint("end")
                    self.audioPlayer.currentTime = self.previousPlayingTime
                    if previousPlaying { self.playPausePlayer() }

                } else {
                    dbprint("began")
                    previousPlayingTime = self.audioPlayer.currentTime
                    playPauseBtn.setTitle("Play Audio", forState: UIControlState.Normal)
                    
                }
            }
        }
        
    }
    
    func testSpeechFromFile(audioFile:String) {
        
        if let modelPath = getModelPath() {
            
            let hmm = (modelPath as NSString).stringByAppendingPathComponent("en-us")
            let lm = (modelPath as NSString).stringByAppendingPathComponent("en-us.lm.dmp")
            let dict = (modelPath as NSString).stringByAppendingPathComponent("cmudict-en-us.dict")
            
            if let config = Config(args: ("-hmm", hmm), ("-lm", lm), ("-dict", dict)) {
                if let decoder = Decoder(config:config) {
                    
                    
                    decoder.decodeSpeechAtPath(audioFile) {
                        
                        if let hyp = $0 {
                            
                            print("Text: \(hyp.text) - Score: \(hyp.score)")
                            print(hyp.text == "Return", "Pass")
                            
                        } else {
                            print("Fail to decode audio")
                        }
                        
                       
                    }
                    
                  
                    
                } else {
                    print("Can't run test without a decoder")
                }
                
            } else {
                print("Can't run test without a valid config")
            }
            
        } else {
            print("Can't access pocketsphinx model. Bundle root: \(NSBundle.mainBundle())")
        }
        
    }

    
}


extension AudioPlayerViewController : AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            self.nextAudioAction(NSNull)
        }
    }
    
    
}


























