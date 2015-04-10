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

    enum PlaybackButton : Int {
        case None
        case Play
        case Pause
        case Resume
    }
    
    // #MARK: - ivars

    var playerStatus: MyAVPlayerStatus = .Unknown
    var player = AVPlayer()
    var playerItem: AVPlayerItem?
    let playerItemKeysToObserve = ["status"]
    var trackDuration: CMTime?
    var pausedAt: CMTime?
    var redrawTimeSliderTimer: NSTimer?
    let redrawTimeSliderInterval = 1.0 // seconds
    var lastBtClicked: PlaybackButton = .None

    @IBOutlet weak var playBtn: UIButton!
    @IBOutlet weak var pauseBtn: UIButton!
    @IBOutlet weak var resumeBtn: UIButton!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var timeSlider: UISlider!
    @IBOutlet weak var currentTimeLbl: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    // #MARK: - UIViewController methods

    override func viewDidLoad() {
        super.viewDidLoad()

        registerAudioSession()
    }

    deinit {
        if playerStatus == .Playing {
            player.pause()
        }

        stopKeyPathsObserving()
    }
    
    // #MARK: - events

    @IBAction func playBtnClicked(sender: AnyObject) {
        // let urlString = "http://goo.gl/oxlCUq"
        // let urlString = "goo.gl/m8XIZv"
        // let urlString = "http://mds.kallisto.ru/Kir_Bulychev_-_Zvjozdy_zovut.mp3"
        let urlString = "http://mds.kallisto.ru/roygbiv/records/mp3/Leonid_Kaganov_-_Choza_griby.mp3"

        lastBtClicked = .Play
        startPlayback(NSURL(string:urlString))
    }

    @IBAction func pauseBtnClicked(sender: AnyObject) {
        lastBtClicked = .Pause
        pausePlayback()
    }

    @IBAction func resumeBtnClicked(sender: AnyObject) {
        lastBtClicked = .Resume
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
        assert(playerItem != nil)

        if let playerItem = object as? AVPlayerItem {
            if keyPath == "status" && playerItem.status == .ReadyToPlay {
                trackDuration = playerItem.duration
                playerStatus = .Playing
                configureRedrawTimer()
                redrawPlaybackControls()
            }
        }
    }

    // #MARK: - playback

    func startPlayback(url: NSURL?) {
        assert(playerStatus == .Unknown)
        assert(url != nil)

        if let url = url {
            playerItem = AVPlayerItem(URL: url)
            player = AVPlayer(playerItem:playerItem)
            player.play()
            startKeyPathsObserving()
            playerStatus = .Starting
            redrawPlaybackControls()
        }
    }
    
    func pausePlayback() {
        assert(playerStatus != .Paused)
        // assert(player.rate > 0)
        // assert(redrawTimeSliderTimer != nil)

        pausedAt = player.currentTime()
        player.pause()
        redrawTimeSliderTimer?.invalidate()
        redrawTimeSliderTimer = nil
        playerStatus = .Paused
        redrawPlaybackControls()
    }
    
    func resumePlayback() {
        assert(playerStatus == .Paused || playerStatus == .TimeChanging)
        assert(player.rate == 0)
        assert(pausedAt != nil)

        player.play()
        if let pausedAt = pausedAt {
            playerStatus = .Playing
            redrawPlaybackControls()
            playerStatus = .Seeking
            redrawPlaybackControls()
            player.seekToTime(pausedAt, completionHandler: seekToTimeCallback)
        }
    }
    
    func playbackSetVolumeTo(value: Float) {

        player.volume = value
    }

    func playbackStartSeeking() {
        assert((playerStatus == .Playing && redrawTimeSliderTimer != nil)
            || (playerStatus == .Paused && redrawTimeSliderTimer == nil)
            || (playerStatus == .TimeChanging && redrawTimeSliderTimer == nil)
            || (playerStatus == .Seeking && redrawTimeSliderTimer == nil))

        redrawTimeSliderTimer?.invalidate()
        redrawTimeSliderTimer = nil
        playerStatus = .TimeChanging
    }

    func playbackCompleteSeeking() {
        assert(playerStatus == .TimeChanging)
        assert(trackDuration != nil)

        if let duration = trackDuration {
            let position = Float(timeSlider.value)
            let value = Float(duration.value) * position
            let seekTo = CMTimeMake(Int64(value), duration.timescale)

            if lastBtClicked == .Pause {
                pausedAt = seekTo
            }
            else {    
                playerStatus = .Seeking
                redrawPlaybackControls()
                player.seekToTime(seekTo, completionHandler: seekToTimeCallback)
            }

        }
    }

    func seekToTimeCallback(success: Bool) {
        assert(playerStatus == .Seeking || playerStatus == .TimeChanging || playerStatus == .Paused)

        if success && playerStatus == .Seeking {
            if player.rate == 0 {
                player.play()
            }
            configureRedrawTimer()
            playerStatus = .Playing
            redrawPlaybackControls()
        }
    }

    func configureRedrawTimer() {
        assert(redrawTimeSliderTimer == nil)

        redrawTimeSliderTimer = NSTimer.scheduledTimerWithTimeInterval(redrawTimeSliderInterval, target: self, selector: Selector("redrawTimeSlider"), userInfo: nil, repeats: true)
    }

    // #MARK: - redrawnings
    
    func redrawPlaybackControls() {
        assert(playBtn != nil)
        assert(pauseBtn != nil)
        assert(resumeBtn != nil)
        assert(volumeSlider != nil)
        assert(timeSlider != nil)
        assert(activityIndicator != nil)

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
        assert(trackDuration != nil)
        assert(timeSlider != nil)

        if let duration = trackDuration {
            let currentTime = player.currentItem.currentTime()
            let position = CMTimeGetSeconds(currentTime) / CMTimeGetSeconds(duration)
            timeSlider.value = Float(position)
            redrawCurentTime()
        }
    }

    func redrawCurentTime() {
        assert(trackDuration != nil)
        assert(timeSlider != nil)
        assert(currentTimeLbl != nil)

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

    // #MARK: - miscellaneous

    func registerAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        var error: NSError?
        
        if audioSession.setCategory(AVAudioSessionCategoryPlayback, error: &error) && audioSession.setActive(true, error: &error) {
            // all fine
        }
        else if let error = error {
            println("registering audio session error: \(error)")
        }
        else {
            println("registering audio session unknown error")
        }
    }
}

