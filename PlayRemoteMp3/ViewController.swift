//
//  ViewController.swift
//  PlayRemoteMp3
//
//  Created by Evgeniy Pozdnyakov on 2015-03-31.
//  Copyright (c) 2015 Evgeniy Pozdnyakov. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    enum MyAVPlayerStatus : Int {
        case Unknown
        case Playing
        case Paused
    }
    
    // #MARK: - ivars

    var player = AVPlayer()
    var playerItem = AVPlayerItem()
    var pausedAt: CMTime?
    var trackDuration: CMTime?
    var playerStatus: MyAVPlayerStatus = .Unknown
    var timer: NSTimer?
    var isSeeking = false

    @IBOutlet weak var remoteMp3PlayBtn: UIButton!
    @IBOutlet weak var remoteMp3PauseBtn: UIButton!
    @IBOutlet weak var remoteMp3ResumeBtn: UIButton!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var seekSlider: UISlider!
    @IBOutlet weak var trackPlayingTime: UILabel!
    
    // #MARK: - UIViewController methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureRemoteMp3Controls()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // #MARK: - event listeners

    @IBAction func remoteMp3PlayBtnClicked(sender: AnyObject) {
        remoteMp3Play()
    }

    @IBAction func remoteMp3PauseBtnClicked(sender: AnyObject) {
        remoteMp3Pause()
    }

    @IBAction func remoteMp3ResumeBtnClicked(sender: AnyObject) {
        remoteMp3Resume()
    }

    @IBAction func remoteMp3VolumeChanged(sender: AnyObject) {
        let slider = sender as UISlider
        remoteMp3SetVolumeTo(slider.value)
    }

    @IBAction func touchDown(sender: UISlider) {
//        remoteMp3Pause()
        isSeeking = true
    }

    @IBAction func touchUpInside(sender: UISlider) {
        if let duration = trackDuration {
            let position = Float(seekSlider.value)
            let value = Float(duration.value) * position
            let seekTo = CMTimeMake(Int64(value), duration.timescale)
            println("seek to \(seekTo)")
            player.seekToTime(seekTo)
        }
        isSeeking = false
    }

    @IBAction func touchUpOutside(sender: UISlider) {
        isSeeking = false
    }

    // #MARK: - helpers

    func remoteMp3Play() {
        //let url = "http://mds.kallisto.ru/Kir_Bulychev_-_Zvjozdy_zovut.mp3"
        let url = "http://mds.kallisto.ru/roygbiv/records/mp3/Leonid_Kaganov_-_Choza_griby.mp3"
        playerItem = AVPlayerItem( URL:NSURL( string:url ) )
        player = AVPlayer(playerItem:playerItem)
        player.addObserver(self, forKeyPath: "rate", options: .New, context: nil)
        player.addObserver(self, forKeyPath: "status", options: .New, context: nil)
        playerItem.addObserver(self, forKeyPath: "timedMetadata", options: .New, context: nil)
        player.rate = 1.0;
        player.play()
    }
    
    func remoteMp3Pause() {
        pausedAt = player.currentTime()
        player.pause()
    }
    
    func remoteMp3Resume() {
        player.play()
        if let pausedAt = pausedAt {
            player.seekToTime(pausedAt)
        }
    }
    
    func remoteMp3SetVolumeTo(value: Float) {
        player.volume = value
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if let object = object as? AVPlayer {
            if object == player {
                if keyPath == "rate" {
                    println("rate changed: \(player.rate)")
                    if player.rate > 0 {
                        playerStatus = .Playing
                        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("configureRemoteMp3Controls"), userInfo: nil, repeats: true)
                    }
                    else {
                        playerStatus = .Paused
                        timer?.invalidate()
                    }
                    configureRemoteMp3Controls()
                }
                else if keyPath == "status" {
                    println("status changed: \(player.status)")
                    if player.status == .Unknown {
                        playerStatus = .Unknown
                        timer?.invalidate()
                        configureRemoteMp3Controls()
                    }
                    else if player.status == .ReadyToPlay {
                        trackDuration = player.currentItem.asset.duration
                    }
                }
            }
        }
        else if let object = object as? AVPlayerItem {
            if object == playerItem {
                if keyPath == "timedMetadata" {
                    println("timedMetadata: \(player.currentItem.timedMetadata)")
                }
            }
        }
        else {
            println("something else")
        }
    }

    func configureRemoteMp3Controls() {
        switch playerStatus {
        case .Unknown:
            remoteMp3PlayBtn.enabled = true
            remoteMp3PauseBtn.enabled = false
            remoteMp3ResumeBtn.enabled = false
            volumeSlider.enabled = false
            seekSlider.enabled = false
        case .Playing:
            remoteMp3PlayBtn.enabled = false
            remoteMp3PauseBtn.enabled = true
            remoteMp3ResumeBtn.enabled = false
            volumeSlider.enabled = true
            seekSlider.enabled = true
            if !isSeeking {
                if let duration = trackDuration {
                    let currentTime = player.currentItem.currentTime()
                    let position = CMTimeGetSeconds(currentTime) / CMTimeGetSeconds(duration)
                    seekSlider.value = Float(position)
                    
                    let currentTimeSeconds = lroundf(Float(CMTimeGetSeconds(currentTime)))
                    let hours = currentTimeSeconds / 3600
                    println("hours: \(hours)")
                    let minutes = currentTimeSeconds / 60 % 60
                    println("minutes: \(minutes)")
                    let seconds = currentTimeSeconds % 60
                    println("seconds: \(seconds)")
                    trackPlayingTime.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                }
            }
        case .Paused:
            remoteMp3PlayBtn.enabled = false
            remoteMp3PauseBtn.enabled = false
            remoteMp3ResumeBtn.enabled = true
            volumeSlider.enabled = true
            seekSlider.enabled = true
        default:
            break        
        }
    }

    deinit {
        if playerStatus == .Playing {
            player.pause()
        }
        
        player.removeObserver(self, forKeyPath: "status")
        player.removeObserver(self, forKeyPath: "rate")
        playerItem.removeObserver(self, forKeyPath: "timedMetadata")
    }
}

