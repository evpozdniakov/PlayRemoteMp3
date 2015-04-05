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
        case SeekingWhilePaused
        case SeekingWhilePlaying
    }
    
    // #MARK: - ivars

    var player = AVPlayer()
    var pausedAt: CMTime?
    var trackDuration: CMTime?
    var playerStatus: MyAVPlayerStatus = .Unknown
    var refreshSliderTimer: NSTimer?
    let refreshSliderEvery = 0.1
    let playerKeysToObserve = ["rate", "status"]

    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var pauseBtn: UIButton!
    @IBOutlet weak var resumeBtn: UIButton!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var currentTimeSlider: UISlider!
    @IBOutlet weak var currentTimeLbl: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
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

    deinit {
        if playerStatus == .Playing {
            player.pause()
        }

        stopObservingPlayerKeyPaths()
    }
    
    // #MARK: - event listeners

    @IBAction func playBtnClicked(sender: AnyObject) {
        startPlayback()
    }

    @IBAction func pauseBtnClicked(sender: AnyObject) {
        pausePlayback()
    }

    @IBAction func resumeBtnClicked(sender: AnyObject) {
        resumePlayback()
    }

    @IBAction func remoteMp3VolumeChanged(sender: UISlider) {
        playbackSetVolumeTo(sender.value)
    }

    @IBAction func touchDown(sender: UISlider) {
       playbackStartSeeking()
    }

    @IBAction func touchUpInside(sender: UISlider) {
        playbackCompleteSeeking()
    }

    @IBAction func touchUpOutside(sender: UISlider) {
        playbackCompleteSeeking()
    }

    func startObservingPlayerKeyPaths() {
        for keyPath in playerKeysToObserve {
            player.addObserver(self, forKeyPath: keyPath, options: .New, context: nil)
        }
    }

    func stopObservingPlayerKeyPaths() {
        for keyPath in playerKeysToObserve {
            player.removeObserver(self, forKeyPath: keyPath)
        }
    }

    // #MARK: - playback

    func startPlayback() {
        let url = "http://goo.gl/oxlCUq"
        // let url = "http://mds.kallisto.ru/Kir_Bulychev_-_Zvjozdy_zovut.mp3"
        // let url = "http://mds.kallisto.ru/roygbiv/records/mp3/Leonid_Kaganov_-_Choza_griby.mp3"
        let playerItem = AVPlayerItem( URL:NSURL( string:url ) )
        player = AVPlayer(playerItem:playerItem)
        startObservingPlayerKeyPaths()
        player.rate = 1.0;
        player.play()
    }
    
    func pausePlayback() {
        pausedAt = player.currentTime()
        player.pause()
    }
    
    func resumePlayback() {
        player.play()
        if let pausedAt = pausedAt {
            player.seekToTime(pausedAt)
        }
    }
    
    func playbackSetVolumeTo(value: Float) {
        player.volume = value
    }

    func playbackStartSeeking() {
        playerStatus = playerStatus == .Playing ? .SeekingWhilePlaying : .SeekingWhilePaused
    }

    func playbackCompleteSeeking() {
        if let duration = trackDuration {
            let position = Float(currentTimeSlider.value)
            let value = Float(duration.value) * position
            let seekTo = CMTimeMake(Int64(value), duration.timescale)

            if playerStatus == .SeekingWhilePaused {
                pausedAt = seekTo
                playerStatus = .Paused
            }
            else {
                player.seekToTime(seekTo)
                playerStatus = .Playing
            }
        }
    }

    // #MARK: - redrawnings
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if let object = object as? AVPlayer {
            if object == player {
                if keyPath == "rate" {
                    if player.status != .ReadyToPlay {
                        println("--- not ready yet: \(player.status)")
                        return;
                    }
                    if player.rate > 0 {
                        println("--- rate > 0")
                        playerStatus = .Playing
                        refreshSliderTimer = NSTimer.scheduledTimerWithTimeInterval(refreshSliderEvery, target: self, selector: Selector("configureRemoteMp3Controls"), userInfo: nil, repeats: true)
                    }
                    else {
                        playerStatus = .Paused
                        refreshSliderTimer?.invalidate()
                    }
                    configureRemoteMp3Controls()
                }
                else if keyPath == "status" {
                    if player.status == .Unknown {
                        playerStatus = .Unknown
                        refreshSliderTimer?.invalidate()
                        configureRemoteMp3Controls()
                    }
                    else if player.status == .ReadyToPlay {
                        println("---ready to play")
                        trackDuration = player.currentItem.asset.duration
                    }
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
            playBtn.enabled = true
            pauseBtn.enabled = false
            resumeBtn.enabled = false
            volumeSlider.enabled = false
            currentTimeSlider.enabled = false
            currentTimeLbl.hidden = true
        case .Playing:
            playBtn.enabled = false
            pauseBtn.enabled = true
            resumeBtn.enabled = false
            volumeSlider.enabled = true
            currentTimeSlider.enabled = true
            if let duration = trackDuration {
                let currentTime = player.currentItem.currentTime()
                let position = CMTimeGetSeconds(currentTime) / CMTimeGetSeconds(duration)
                currentTimeSlider.value = Float(position)
                
                let currentTimeSeconds = lroundf(Float(CMTimeGetSeconds(currentTime)))
                let hours = currentTimeSeconds / 3600
                let minutes = currentTimeSeconds / 60 % 60
                let seconds = currentTimeSeconds % 60
                currentTimeLbl.hidden = false
                currentTimeLbl.text = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            }
        case .Paused:
            playBtn.enabled = false
            pauseBtn.enabled = false
            resumeBtn.enabled = true
            volumeSlider.enabled = true
            currentTimeSlider.enabled = true
        default:
            break        
        }
    }
}

