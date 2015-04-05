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
        case SeekingWhilePaused
        case SeekingWhilePlaying
    }
    
    // #MARK: - ivars

    var player = AVPlayer()
    var pausedAt: CMTime?
    var trackDuration: CMTime?
    var playerStatus: MyAVPlayerStatus = .Unknown
    var redrawTimeSliderTimer: NSTimer?
    let refreshSliderEvery = 0.1
    let playerKeysToObserve = ["rate", "status"]

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

        stopObservingPlayerKeyPaths()
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

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if let player = object as? AVPlayer {
            if keyPath == "rate" {
                if player.status != .ReadyToPlay {
                    // ignore as player isn't ready to play yet
                    return;
                }

                if player.rate > 0 {
                    playbackDidStart()
                }
                else {
                    playbackDidPause()
                }
            }
            else if keyPath == "status" {
                // ?
            }
        }
    }

    // #MARK: - playback

    func startPlayback() {
        let url = "http://goo.gl/oxlCUq"
        // let url = "http://mds.kallisto.ru/Kir_Bulychev_-_Zvjozdy_zovut.mp3"
        // let url = "http://mds.kallisto.ru/roygbiv/records/mp3/Leonid_Kaganov_-_Choza_griby.mp3"
        let playerItem = AVPlayerItem( URL:NSURL( string:url ) )
        player = AVPlayer(playerItem:playerItem)
        player.play()
        player.rate = 1.0;
        startObservingPlayerKeyPaths()
        playerStatus = .Starting
        redrawPlaybackControls()
    }

    func playbackDidStart() {
        trackDuration = player.currentItem.asset.duration
        playerStatus = .Playing
        configureRedrawTimer()
        activityIndicator.stopAnimating()
        redrawPlaybackControls()
    }
    
    func pausePlayback() {
        pausedAt = player.currentTime()
        player.pause()
    }

    func playbackDidPause() {
        playerStatus = .Paused
        redrawTimeSliderTimer?.invalidate()
        redrawPlaybackControls()
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
        redrawTimeSliderTimer?.invalidate()

        switch playerStatus {
        case .Playing:
            playerStatus = .SeekingWhilePlaying
        case .Paused:
            playerStatus = .SeekingWhilePaused
        default:
            break
        }

        redrawPlaybackControls()
    }

    func playbackCompleteSeeking() {
        if let duration = trackDuration {
            let position = Float(timeSlider.value)
            let value = Float(duration.value) * position
            let seekTo = CMTimeMake(Int64(value), duration.timescale)

            switch playerStatus {
            case .SeekingWhilePlaying:
                player.seekToTime(seekTo) { success in
                    if success {
                        self.configureRedrawTimer()
                        self.playerStatus = .Playing
                        self.redrawPlaybackControls()
                    }
                }
           case .SeekingWhilePaused:
                player.play()
                if let pausedAt = pausedAt {
                    player.seekToTime(seekTo)
                }
                player.seekToTime(seekTo) { success in
                    if success {
                        self.pausedAt = self.player.currentTime()
                        self.player.pause()
                        self.playerStatus = .Paused
                        self.redrawPlaybackControls()
                    }
                }
                redrawPlaybackControls()
            default:
                break
            }

        }
    }

    func configureRedrawTimer() {
        redrawTimeSliderTimer = NSTimer.scheduledTimerWithTimeInterval(refreshSliderEvery, target: self, selector: Selector("redrawTimeSlider"), userInfo: nil, repeats: true)
    }

    // #MARK: - redrawnings
    
    func redrawPlaybackControls() {
        switch playerStatus {
        /* case .Unknown:
            playBtn.enabled = true
            pauseBtn.enabled = false
            resumeBtn.enabled = false
            volumeSlider.enabled = false
            timeSlider.enabled = false
            currentTimeLbl.hidden = true */
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
        case .SeekingWhilePlaying, .SeekingWhilePaused:
            if !activityIndicator.isAnimating() { activityIndicator.startAnimating() }
        default:
            break        
        }
    }

    func redrawTimeSlider() {
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

