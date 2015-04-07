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
        case Starting
        case Playing
        case Paused
        case TimeChanging
        case Seeking
    }
    
    // #MARK: - ivars

    var playerStatus: MyAVPlayerStatus = .Unknown
    var player = AVPlayer()
    var playerItem: AVPlayerItem?
    let playerItemKeysToObserve = ["status"]
    var trackDuration: CMTime?
    var pausedAt: CMTime?
    var redrawTimeSliderTimer: NSTimer?
    let refreshSliderEvery = 0.1
    var isTimeSliderMoved = false

    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var pauseBtn: UIButton!
    @IBOutlet weak var resumeBtn: UIButton!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var currentTimeLbl: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // #MARK: - UIViewController methods

    deinit {
        if playerStatus == .Playing {
            player.pause()
        }

        stopKeyPathsObserving()
    }
    
    // #MARK: - events

    @IBAction func playBtnClicked(sender: AnyObject) {
        startPlayback()
    }

    @IBAction func pauseBtnClicked(sender: AnyObject) {
        pausePlayback()
    }

    @IBAction func resumeBtnClicked(sender: AnyObject) {
        resumePlayback()
    }

    @IBAction func volumeSliderMoved(sender: UISlider) {
        playbackSetVolumeTo(sender.value)
    }

    @IBAction func timeSliderTouched(sender: UISlider) {
       playbackStartSeeking()
    }

    @IBAction func timeSliderMoved(sender: UISlider) {
       redrawCurentTime()
    }

    @IBAction func timeSliderReleased(sender: UISlider) {
        playbackCompleteSeeking()
    }

    func startKeyPathsObserving() {
        /* for keyPath in playerKeysToObserve {
            player.addObserver(self, forKeyPath: keyPath, options: .New, context: nil)
        } */
        for keyPath in playerItemKeysToObserve {
            playerItem?.addObserver(self, forKeyPath: keyPath, options: .New, context: nil)
        }
    }

    func stopKeyPathsObserving() {
        /* for keyPath in playerKeysToObserve {
            player.removeObserver(self, forKeyPath: keyPath)
        } */
        for keyPath in playerItemKeysToObserve {
            playerItem?.removeObserver(self, forKeyPath: keyPath)
        }
    }

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if let playerItem = object as? AVPlayerItem {
            if keyPath == "status" && playerItem.status == .ReadyToPlay {
                trackDuration = playerItem.duration
                playerStatus = .Playing
                println("---- send to reset 0 (stasrt)")
                configureRedrawTimer()
                redrawPlaybackControls()
            }
        }
    }

    // #MARK: - playback

    func startPlayback() {
        // let url = "http://goo.gl/oxlCUq"
        let url = "http://mds.kallisto.ru/Kir_Bulychev_-_Zvjozdy_zovut.mp3"
        // let url = "http://mds.kallisto.ru/roygbiv/records/mp3/Leonid_Kaganov_-_Choza_griby.mp3"
        // let url = "goo.gl/m8XIZv"
        playerItem = AVPlayerItem( URL:NSURL( string:url ) )
        player = AVPlayer(playerItem:playerItem)
        player.play()
        startKeyPathsObserving()
        playerStatus = .Starting
        redrawPlaybackControls()
    }
    
    func pausePlayback() {
        pausedAt = player.currentTime()
        player.pause()
        println("---- invalidate 1 -----")
        redrawTimeSliderTimer?.invalidate()
        playerStatus = .Paused
        redrawPlaybackControls()
    }
    
    func resumePlayback() {
        player.play()

        if let pausedAt = pausedAt {
            player.seekToTime(pausedAt)

            if isTimeSliderMoved {
                isTimeSliderMoved = false
                playbackCompleteSeeking()
            }
            else {
                println("---- send to reset 1")
                configureRedrawTimer()
                playerStatus = .Playing
                redrawPlaybackControls()
            }
        }
    }
    
    func playbackSetVolumeTo(value: Float) {
        player.volume = value
    }

    func playbackStartSeeking() {
        println("---- invalidate 2 -----")
        redrawTimeSliderTimer?.invalidate()
        playerStatus = .TimeChanging
    }

    func playbackCompleteSeeking() {
        if let duration = trackDuration {
            if player.rate > 0 {
                let position = Float(timeSlider.value)
                let value = Float(duration.value) * position
                let seekTo = CMTimeMake(Int64(value), duration.timescale)
    
                player.seekToTime(seekTo) { success in
                    if success {
                        println("---- send to reset 2")
                        self.configureRedrawTimer()
                        self.playerStatus = .Playing
                        self.redrawPlaybackControls()
                    }
                }                

                playerStatus = .Seeking
                redrawPlaybackControls()
            }
            else {
                isTimeSliderMoved = true
            }

        }
    }

    func configureRedrawTimer() {
        redrawTimeSliderTimer = NSTimer.scheduledTimerWithTimeInterval(refreshSliderEvery, target: self, selector: Selector("redrawTimeSlider"), userInfo: nil, repeats: true)
    }

    // #MARK: - redrawnings
    
    func redrawPlaybackControls() {
        switch playerStatus {
        case .Starting:
            if playBtn.enabled { playBtn.enabled = false }
            if pauseBtn.enabled { pauseBtn.enabled = false }
            if resumeBtn.enabled { resumeBtn.enabled = false }
            if volumeSlider.enabled { volumeSlider.enabled = false }
            if timeSlider.enabled { timeSlider.enabled = false }
            if !activityIndicator.isAnimating() { activityIndicator.startAnimating() }
        case .Playing:
            if playBtn.enabled { playBtn.enabled = false }
            if !pauseBtn.enabled { pauseBtn.enabled = true }
            if resumeBtn.enabled { resumeBtn.enabled = false }
            if !volumeSlider.enabled { volumeSlider.enabled = true }
            if !timeSlider.enabled { timeSlider.enabled = true }
            if activityIndicator.isAnimating() { activityIndicator.stopAnimating() }
            redrawTimeSlider()
        case .Paused:
            if playBtn.enabled { playBtn.enabled = false }
            if pauseBtn.enabled { pauseBtn.enabled = false }
            if !resumeBtn.enabled { resumeBtn.enabled = true }
            if !volumeSlider.enabled { volumeSlider.enabled = true }
            if !timeSlider.enabled { timeSlider.enabled = true }
            if activityIndicator.isAnimating() { activityIndicator.stopAnimating() }
        case .Seeking:
            if !activityIndicator.isAnimating() { activityIndicator.startAnimating() }
        default:
            break        
        }
    }

    func redrawTimeSlider() {
        // println("---- redraw time slider and current time ----")
        if let duration = trackDuration {
            let currentTime = player.currentItem.currentTime()
            let position = CMTimeGetSeconds(currentTime) / CMTimeGetSeconds(duration)
            timeSlider.value = Float(position)
            redrawCurentTime()
        }
    }

    func redrawCurentTime() {
        if let duration = trackDuration {
            let seconds = Int( Float(CMTimeGetSeconds(duration)) * timeSlider.value )
            let minutes = seconds / 60
            let hours = minutes / 60

            currentTimeLbl.text = String(format: "%02d:%02d:%02d", hours, minutes%60, seconds%60)

            if currentTimeLbl.hidden {
                currentTimeLbl.hidden = false
            }
        }
    }
}

