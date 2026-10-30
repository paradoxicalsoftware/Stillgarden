import Cocoa
import SwiftUI
import AVFoundation

struct Flower: Codable, Identifiable {
    var id = UUID()
    var kind: Int
    var x: Double
    var y: Double
    var age: Double
    var snow: Double? = nil
}
struct GardenState: Codable {
    var flowers: [Flower] = []
    var speed: Double = 1
    var pinned = true
    var reminders = false
    var interval: Double = 15
    var duration: Double = 45
    var soundEnabled: Bool? = nil
    var volume: Double? = nil
    var gardenOnly: Bool? = nil
    var wildlifeAge: Double? = nil
    var daylightMode: String? = nil
    var cycleHour: Double? = nil
    var daySpeed: Double? = nil
    var weatherMode: String? = nil
    var seasonMode: String? = nil
    var southernHemisphere: Bool? = nil
    var lightningEnabled: Bool? = nil
    var groundSnow: Double? = nil
    var savedAt = Date()
}
let names = ["Daisy", "Poppy", "Cosmos", "Lavender", "Sunflower", "Cornflower", "Marigold", "Tulip", "Coneflower", "Bluebell"]
let growTimes: [Double] = [1200, 1800, 2400, 2700, 3600, 2100, 1500, 2700, 3000, 2400]
let colors: [Color] = [Color(red:0.99,green:0.96,blue:0.82), Color(red:0.94,green:0.35,blue:0.25), Color(red:0.91,green:0.57,blue:0.68), Color(red:0.64,green:0.55,blue:0.83), Color(red:1,green:0.76,blue:0.22), Color(red:0.35,green:0.57,blue:0.93), Color(red:1,green:0.55,blue:0.14), Color(red:0.95,green:0.36,blue:0.56), Color(red:0.78,green:0.47,blue:0.76), Color(red:0.45,green:0.48,blue:0.87)]
let ink = Color(red:0.18,green:0.27,blue:0.20)

struct StormStrike: Identifiable {
    let id = UUID()
    let occurredAt: Date
    let delay: Double
    let x: Double
    let seed: Double
    let variant: Int
    let strength: Double
    var thunderPlayed = false
    var thunderAt: Date { occurredAt.addingTimeInterval(delay) }
    static func random(at date: Date) -> StormStrike {
        .init(occurredAt:date,delay:Double.random(in:1.8...8.5),x:Double.random(in:0.18...0.82),seed:Double.random(in:0...1000),variant:Int.random(in:0...2),strength:Double.random(in:0.65...1))
    }
}
struct ThunderVoice { let player: AVAudioPlayer; let gain: Double }
func snowing(season: String, weather: String) -> Bool { season == "winter" || weather == "snow" }

class Garden: ObservableObject {
    @Published var state = GardenState()
    @Published var selected: UUID?
    @Published var planting: Int? = nil
    @Published var settings = false
    @Published var now = Date()
    @Published var hidden = false
    @Published var message = "A little room to breathe."
    @Published var controlsVisible = true
    @Published var godMode = false
    @Published var resetBackup: GardenState?
    var soundPlayers: [String:AVAudioPlayer] = [:]
    var audioStarted = false
    @Published var strikes: [StormStrike] = []
    var nextStrikeAt: Date?
    var thunderVoices: [ThunderVoice] = []
    var owlPlayer: AVAudioPlayer?
    var owlGain = 1.0
    var nextOwlAt: Date?
    var weatherTransitionFrom: WeatherMix?
    var weatherTransitionAt = Date()
    var hoverTimer: Timer?
    var lastEdge = Date()
    var lightTransitionFrom: Double?
    var lightTransitionAt = Date()
    var lightTransitionDuration = 2.0
    var pointer: CGPoint?
    var surfaceSize = CGSize.zero
    var immersive: Bool { state.gardenOnly ?? true }
    var soundOn: Bool { state.soundEnabled ?? true }
    var showControls: Bool { !immersive || controlsVisible || settings || planting != nil }
    var nextReveal = Date()
    var hideAt: Date?
    var timer: Timer?
    var lastTick = Date()
    var saveTicks = 0
    weak var window: NSWindow?
    let saveURL: URL
    var backupURL: URL { saveURL.deletingLastPathComponent().appendingPathComponent("before-reset.json") }
    init(saveURL: URL? = nil, startTimer: Bool = true) {
        self.saveURL = saveURL ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Stillgarden/garden.json")
        if let data=try? Data(contentsOf:backupURL) { resetBackup=try? JSONDecoder().decode(GardenState.self,from:data) }
        if let data = try? Data(contentsOf:self.saveURL), let s = try? JSONDecoder().decode(GardenState.self,from:data) {
            state = s
            let elapsed=max(0,Date().timeIntervalSince(s.savedAt))
            advanceSnow(elapsed,endingAt:Date())
            advance(elapsed)
        } else {
            state.flowers = [Flower(kind:0,x:0.29,y:0.80,age:1200),Flower(kind:2,x:0.53,y:0.76,age:1750),Flower(kind:4,x:0.70,y:0.85,age:2900)]
        }
        if startTimer { timer = Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in self?.tick() } }
    }
    func rawHour(at date: Date) -> Double {
        if (state.daylightMode ?? "system") == "system" {
            let parts = Calendar.current.dateComponents([.hour,.minute,.second,.nanosecond],from:date)
            return Double(parts.hour ?? 12)+Double(parts.minute ?? 0)/60+Double(parts.second ?? 0)/3600+Double(parts.nanosecond ?? 0)/3_600_000_000_000
        }
        let extra = state.daylightMode == "cycle" ? max(0,date.timeIntervalSince(lastTick))*(state.daySpeed ?? 60)/3600 : 0
        return ((state.cycleHour ?? 12)+extra).truncatingRemainder(dividingBy:24)
    }
    func displayHour(at date: Date) -> Double {
        let target = rawHour(at:date)
        guard let from = lightTransitionFrom else { return target }
        let fraction = min(1,max(0,date.timeIntervalSince(lightTransitionAt)/lightTransitionDuration))
        let ease = fraction*fraction*(3-2*fraction)
        let delta = (target-from+36).truncatingRemainder(dividingBy:24)-12
        return (from+delta*ease+24).truncatingRemainder(dividingBy:24)
    }
    func setDayMode(_ mode: String) {
        let date = Date(), hour = displayHour(at:Date()); tick(); state.cycleHour = hour; state.daylightMode = mode
        lightTransitionFrom = hour; lightTransitionAt = date; lightTransitionDuration = 2; save()
    }
    func setManualHour(_ hour: Double) {
        let date = Date(), from = displayHour(at:Date()); tick(); state.cycleHour = hour
        lightTransitionFrom = from; lightTransitionAt = date; lightTransitionDuration = 0.3; save()
    }
    func advanceSnow(_ seconds: Double, endingAt end: Date) {
        guard seconds > 0 else { return }
        let preferred=state.daylightMode == "cycle" ? min(120,max(1,3600/(state.daySpeed ?? 60))) : 120
        let steps=max(1,min(2880,Int(ceil(seconds/preferred))))
        let step=seconds/Double(steps), start=end.addingTimeInterval(-seconds)
        for i in 0..<steps {
            let offset=(Double(i)+0.5)*step, date=start.addingTimeInterval(offset)
            let seasonName=season(at:date), weatherName=weatherName(at:date)
            let mix=WeatherMix.named(weatherName)
            let snowfall=snowing(season:seasonName,weather:weatherName) ? mix.rain : 0
            let hour: Double
            if (state.daylightMode ?? "system") == "system" {
                let parts=Calendar.current.dateComponents([.hour,.minute],from:date)
                hour=Double(parts.hour ?? 12)+Double(parts.minute ?? 0)/60
            } else { hour=((state.cycleHour ?? 12)+(state.daylightMode == "cycle" ? offset*(state.daySpeed ?? 60)/3600 : 0)).truncatingRemainder(dividingBy:24) }
            let temperature=climateTemperature(season:seasonName,hour:hour,snowfall:snowfall)
            state.groundSnow=snowDepth(state.groundSnow ?? 0,seconds:step,snowfall:snowfall,temperature:temperature,exposed:false)
            for index in state.flowers.indices { state.flowers[index].snow=snowDepth(state.flowers[index].snow ?? 0,seconds:step,snowfall:snowfall,temperature:temperature,exposed:true) }
        }
    }
    func resetGarden() {
        do {
            try FileManager.default.createDirectory(at:saveURL.deletingLastPathComponent(),withIntermediateDirectories:true)
            try JSONEncoder().encode(state).write(to:backupURL,options:.atomic)
            resetBackup=state;state.flowers=[];state.groundSnow=0;state.wildlifeAge=0
            selected=nil;planting=nil;message="Garden reset. Undo is available below.";save()
        } catch { message="Reset cancelled: could not save an undo copy." }
    }
    func undoGardenReset() {
        guard let backup=resetBackup else { return }
        state.flowers=backup.flowers;state.groundSnow=backup.groundSnow;state.wildlifeAge=backup.wildlifeAge
        selected=nil;planting=nil;message="Your previous garden has been restored.";save()
    }
    func advance(_ seconds: Double) {
        if state.daylightMode == "cycle" { state.cycleHour = ((state.cycleHour ?? 12)+seconds*(state.daySpeed ?? 60)/3600).truncatingRemainder(dividingBy:24) }
        state.wildlifeAge = (state.wildlifeAge ?? 0) + seconds * state.speed
        for i in state.flowers.indices { state.flowers[i].age = state.flowers[i].age + seconds * state.speed }
    }
    func season(at date: Date) -> String {
        if let mode = state.seasonMode, mode != "calendar" { return mode }
        return calendarSeason(month:Calendar.current.component(.month,from:date),southern:state.southernHemisphere ?? false)
    }
    func weatherName(at date: Date) -> String {
        if let mode = state.weatherMode, mode != "auto" { return mode == "rain" && season(at:date) == "winter" ? "snow" : mode }
        return automaticWeather(slot:Int(date.timeIntervalSince1970/480),season:season(at:date))
    }
    func weather(at date: Date) -> WeatherMix {
        var target = WeatherMix.named(weatherName(at:date))
        if (state.weatherMode ?? "auto") == "auto" {
            let seconds=date.timeIntervalSince1970, slot=Int(seconds/480)
            let previous=WeatherMix.named(automaticWeather(slot:slot-1,season:season(at:date)))
            target = previous.blended(to:target,amount:seconds.truncatingRemainder(dividingBy:480)/25)
        }
        if let from = weatherTransitionFrom, date.timeIntervalSince(weatherTransitionAt) < 4 {
            return from.blended(to:target,amount:date.timeIntervalSince(weatherTransitionAt)/4)
        }
        return target
    }
    func setWeather(_ mode: String) {
        weatherTransitionFrom = weather(at:Date()); weatherTransitionAt = Date(); state.weatherMode = mode; save(); updateAudio()
    }
    func startExperience() {
        audioStarted = true; updateAudio()
        hoverTimer = Timer.scheduledTimer(withTimeInterval:0.15,repeats:true) { [weak self] _ in self?.trackEdge(); self?.updateOneShots(at:Date()) }
        updateChrome()
    }
    func updateAudio() {
        guard audioStarted else { return }
        let date=Date(), seasonName=season(at:date), mix=weather(at:date)
        let day=pollinatorActivity(displayHour(at:date))
        let gains: [String:Double] = ["day-"+seasonName:day*(1-mix.rain*0.7), "night-"+seasonName:(1-day)*(1-mix.rain*0.45), "rain":snowing(season:seasonName,weather:weatherName(at:date)) ? 0 : mix.rain, "wind":mix.wind]
        for key in Array(soundPlayers.keys) where gains[key] == nil { soundPlayers[key]?.stop(); soundPlayers.removeValue(forKey:key) }
        for (key,gain) in gains {
            if soundPlayers[key] == nil, let url=Bundle.main.url(forResource:key,withExtension:"wav") {
                do { let player=try AVAudioPlayer(contentsOf:url); player.numberOfLoops = -1; player.volume = 0; player.currentTime = date.timeIntervalSince1970.truncatingRemainder(dividingBy:60); player.prepareToPlay(); soundPlayers[key]=player }
                catch { message = "Could not load a soundscape." }
            }
            guard let player=soundPlayers[key] else { continue }
            if soundOn && !hidden {
                if !player.isPlaying { player.currentTime = date.timeIntervalSince1970.truncatingRemainder(dividingBy:60); player.play() }
                player.setVolume(Float((state.volume ?? 0.22)*gain),fadeDuration:0.9)
            } else { player.pause() }
        }
    }
    func updateOneShots(at date: Date) {
        guard audioStarted else { return }
        let mix=weather(at:date)
        if hidden || mix.storm < 0.15 {
            nextStrikeAt = nil
            if !strikes.isEmpty { strikes.removeAll() }
            if hidden { thunderVoices.forEach { $0.player.stop() }; thunderVoices.removeAll() }
        } else {
            if nextStrikeAt == nil { nextStrikeAt = date.addingTimeInterval(Double.random(in:3...9)) }
            if let next=nextStrikeAt, date >= next {
                strikes.append(.random(at:date))
                nextStrikeAt = date.addingTimeInterval(Double.random(in:14...42))
            }
            for i in strikes.indices where !strikes[i].thunderPlayed && date >= strikes[i].thunderAt {
                strikes[i].thunderPlayed = true
                if soundOn, let url=Bundle.main.url(forResource:"thunder-\(strikes[i].variant)",withExtension:"wav"), let player=try? AVAudioPlayer(contentsOf:url) {
                    let gain=strikes[i].strength*mix.storm
                    player.volume=Float((state.volume ?? 0.22)*gain)
                    player.pan=Float((strikes[i].x-0.5)*1.2)
                    player.prepareToPlay();player.play()
                    thunderVoices.append(.init(player:player,gain:gain))
                }
            }
            if strikes.contains(where:{date.timeIntervalSince($0.occurredAt)>35}) { strikes.removeAll { date.timeIntervalSince($0.occurredAt)>35 } }
        }
        thunderVoices.removeAll { !$0.player.isPlaying }
        if hidden || !soundOn {
            thunderVoices.forEach { $0.player.stop() };thunderVoices.removeAll();owlPlayer?.stop();nextOwlAt=nil
            return
        }
        for voice in thunderVoices { voice.player.volume=Float((state.volume ?? 0.22)*voice.gain) }
        let night=1-pollinatorActivity(displayHour(at:date))
        if night < 0.1 { owlPlayer?.setVolume(0,fadeDuration:1);nextOwlAt=nil;return }
        owlPlayer?.volume=Float((state.volume ?? 0.22)*night*(1-mix.rain*0.65)*owlGain)
        if nextOwlAt == nil { nextOwlAt=date.addingTimeInterval(Double.random(in:6...20)) }
        if let next=nextOwlAt,date >= next {
            if let url=Bundle.main.url(forResource:"owl-call",withExtension:"wav"),let player=try? AVAudioPlayer(contentsOf:url) {
                owlGain = Double.random(in:0.6...1)
                player.volume=Float((state.volume ?? 0.22)*night*(1-mix.rain*0.65)*owlGain)
                player.pan=Float.random(in:-0.55...0.55);player.prepareToPlay();player.play();owlPlayer=player
            }
            nextOwlAt=date.addingTimeInterval(Double.random(in:32...75))
        }
    }

    func toggleSound() { state.soundEnabled = !soundOn; updateAudio(); updateOneShots(at:Date()); save() }
    func updateChrome() {
        for button in [NSWindow.ButtonType.closeButton,.miniaturizeButton,.zoomButton] { window?.standardWindowButton(button)?.isHidden = immersive }
        window?.isMovableByWindowBackground = true
    }
    func trackEdge() {
        guard !hidden else { return }
        let x = pointer?.x ?? -100, y = pointer?.y ?? -100
        let inside = pointer != nil
        let edge = inside && (x < 24 || x > surfaceSize.width-24 || y < 24 || y > surfaceSize.height-24)
        let overControls = inside && controlsVisible && (y < 100 || y > surfaceSize.height-220)
        if edge || overControls || settings || planting != nil { lastEdge = Date(); if !controlsVisible { controlsVisible = true } }
        else if Date().timeIntervalSince(lastEdge) > 1.1 && controlsVisible { controlsVisible = false; selected = nil }
    }
    func tick() {
        let date = Date(); let elapsed=max(0,date.timeIntervalSince(lastTick)); advanceSnow(elapsed,endingAt:date); advance(elapsed); lastTick = date; now = date; updateAudio()
        saveTicks += 1; if saveTicks >= 10 { save(); saveTicks = 0 }
        if state.reminders && !settings {
            if hidden && date >= nextReveal { reveal(); hideAt = date.addingTimeInterval(state.duration) }
            else if !hidden, let end = hideAt, date >= end { rest() }
        }
    }
    func save() {
        state.savedAt = Date()
        do { try FileManager.default.createDirectory(at:saveURL.deletingLastPathComponent(),withIntermediateDirectories:true); try JSONEncoder().encode(state).write(to:saveURL,options:.atomic) }
        catch { message = "Could not save garden: \(error.localizedDescription)" }
    }
    func pin() { window?.level = state.pinned ? .floating : .normal; save() }
    func fade(_ alpha: Double) { NSAnimationContext.runAnimationGroup { c in c.duration = 1.4; window?.animator().alphaValue = alpha } }
    func rest() { hidden = true; hideAt = nil; nextReveal = Date().addingTimeInterval(state.interval * 60); fade(0); window?.ignoresMouseEvents = true; updateAudio(); updateOneShots(at:Date()) }
    func reveal() { hidden = false; window?.ignoresMouseEvents = false; window?.orderFrontRegardless(); fade(1); updateAudio() }
    func configureReminders() {
        if state.reminders { hideAt = Date().addingTimeInterval(state.duration) } else { hideAt = nil; reveal() }; save()
    }
    func plant(at point: CGPoint, in size: CGSize) {
        guard let kind = planting else { selected = nil; return }
        guard state.flowers.count < 30 else { message = "Your garden is full. Remove a flower to make room."; return }
        let f = Flower(kind:kind,x:min(0.92,max(0.08,point.x/size.width)),y:min(0.94,max(0.58,point.y/size.height)),age:0)
        state.flowers.append(f); selected = f.id; planting = nil; message = "A new \(names[kind].lowercased()) begins."; save()
    }
    func boost(bloom: Bool) { guard let i = state.flowers.firstIndex(where:{$0.id == selected}) else { return }; state.flowers[i].age = bloom ? max(state.flowers[i].age,growTimes[state.flowers[i].kind]) : state.flowers[i].age + 600; save() }
}

func lifeStage(_ age: Double) -> Int { let t = age.truncatingRemainder(dividingBy:2400); return t < 800 ? 0 : (t < 1400 ? 1 : 2) }
struct PlantHabit {
    let height: Double
    let heads: Int
    let basal: Bool
    let spread: Double
}
let habits: [PlantHabit] = [
    .init(height:112,heads:5,basal:true,spread:42),
    .init(height:138,heads:4,basal:false,spread:48),
    .init(height:145,heads:7,basal:false,spread:55),
    .init(height:170,heads:7,basal:true,spread:42),
    .init(height:166,heads:4,basal:false,spread:50),
    .init(height:126,heads:6,basal:false,spread:43),
    .init(height:95,heads:7,basal:false,spread:49),
    .init(height:130,heads:3,basal:true,spread:27),
    .init(height:145,heads:4,basal:true,spread:43),
    .init(height:130,heads:3,basal:true,spread:32)
]
func beeFacing(_ phase: Double) -> Double { cos(phase) < 0 ? -1 : 1 }
func headCount(_ age: Double, _ kind: Int) -> Int { 1 + min(habits[kind].heads-1,Int(max(0,age/growTimes[kind]-1))) }

func drawHead(_ ctx: GraphicsContext, at tip: CGPoint, kind: Int, bloom: Double, radius: Double) {
    var c = ctx; c.translateBy(x:tip.x,y:tip.y)
    let r = radius * bloom
    if bloom < 0.08 {
        c.fill(Path(ellipseIn:CGRect(x:-3,y:-6,width:6,height:10)),with:.color(.init(red:0.40,green:0.53,blue:0.22))); return
    }
    if kind == 3 {
        // Tapered whorls of small florets, separated by visible stem.
        let length = 46*bloom
        var axis = Path(); axis.move(to:.zero); axis.addLine(to:CGPoint(x:0,y:-length)); c.stroke(axis,with:.color(.init(red:0.42,green:0.48,blue:0.34)),lineWidth:1.1)
        for tier in 0..<10 {
            let taper = 1-Double(tier)*0.065
            for side in [-1.0,1] {
                let x = side*(2.3+2.5*taper), y = -Double(tier)*length/10
                var floret = Path(); floret.move(to:CGPoint(x:0,y:y+2)); floret.addQuadCurve(to:CGPoint(x:x*1.6,y:y-4),control:CGPoint(x:x*2,y:y+3)); floret.addQuadCurve(to:CGPoint(x:0,y:y+2),control:CGPoint(x:x,y:y-7))
                c.fill(floret,with:.linearGradient(Gradient(colors:[Color(red:0.77,green:0.68,blue:0.89),Color(red:0.39,green:0.28,blue:0.58)]),startPoint:CGPoint(x:x,y:y-5),endPoint:CGPoint(x:0,y:y+2)))
            }
        }; return
    }
    if kind == 7 {
        for layer in 0..<2 { for n in -1...1 {
            let x = Double(n)*r*0.35
            var petal = Path(); petal.move(to:CGPoint(x:0,y:6)); petal.addCurve(to:CGPoint(x:x-r*0.35,y:-r*1.3),control1:CGPoint(x:-r*0.8,y:-r*0.1),control2:CGPoint(x:x-r*0.45,y:-r)); petal.addQuadCurve(to:CGPoint(x:x+r*0.35,y:-r*1.3),control:CGPoint(x:x,y:-r*1.6)); petal.addCurve(to:CGPoint(x:0,y:6),control1:CGPoint(x:x+r*0.5,y:-r*0.8),control2:CGPoint(x:r*0.7,y:0))
            c.fill(petal,with:.linearGradient(Gradient(colors:[layer == 0 ? colors[kind].opacity(0.75) : colors[kind],Color(red:0.58,green:0.16,blue:0.30)]),startPoint:CGPoint(x:x-5,y:-r),endPoint:CGPoint(x:8,y:8)))
            var vein = Path(); vein.move(to:CGPoint(x:x,y:-r*1.15)); vein.addQuadCurve(to:CGPoint(x:0,y:3),control:CGPoint(x:x+3,y:-r*0.4)); c.stroke(vein,with:.color(.white.opacity(0.13)),lineWidth:0.6)
        }}; return
    }
    if kind == 9 {
        var raceme = Path(); raceme.move(to:CGPoint(x:0,y:8)); raceme.addQuadCurve(to:CGPoint(x:12,y:-40*bloom),control:CGPoint(x:-6,y:-36*bloom)); c.stroke(raceme,with:.color(.init(red:0.28,green:0.40,blue:0.21)),lineWidth:1.4)
        for n in 0..<5 {
            let x = 2+Double(n)*2, y = -Double(n)*8*bloom
            var pedicel = Path(); pedicel.move(to:CGPoint(x:x-4,y:y-4)); pedicel.addQuadCurve(to:CGPoint(x:x+6,y:y),control:CGPoint(x:x+6,y:y-10)); c.stroke(pedicel,with:.color(ink.opacity(0.7)),lineWidth:0.8)
            var bell = Path(); bell.move(to:CGPoint(x:x+3,y:y)); bell.addCurve(to:CGPoint(x:x+1,y:y+12*bloom),control1:CGPoint(x:x-1,y:y+4),control2:CGPoint(x:x+4,y:y+9)); bell.addQuadCurve(to:CGPoint(x:x+14,y:y+12*bloom),control:CGPoint(x:x+7,y:y+17*bloom)); bell.addCurve(to:CGPoint(x:x+8,y:y),control1:CGPoint(x:x+10,y:y+7),control2:CGPoint(x:x+12,y:y+3)); bell.closeSubpath()
            c.fill(bell,with:.linearGradient(Gradient(colors:[Color(red:0.66,green:0.65,blue:0.94),Color(red:0.28,green:0.25,blue:0.59)]),startPoint:CGPoint(x:x,y:y),endPoint:CGPoint(x:x+14,y:y+10)))
        }; return
    }
    if kind == 8 {
        // Drooping ray florets around a raised, textured cone.
        for n in 0..<12 {
            let a = Double(n)*2 * .pi/12
            let start = CGPoint(x:cos(a)*5,y:sin(a)*3)
            let end = CGPoint(x:cos(a)*r,y:8+abs(sin(a))*r*0.8)
            var petal = Path(); petal.move(to:start); petal.addQuadCurve(to:end,control:CGPoint(x:end.x*0.6-5,y:end.y*0.6)); petal.addQuadCurve(to:start,control:CGPoint(x:end.x*0.6+5,y:end.y*0.6+4))
            c.fill(petal,with:.linearGradient(Gradient(colors:[colors[kind],Color(red:0.49,green:0.25,blue:0.44)]),startPoint:start,endPoint:end))
        }
        let dome = CGRect(x:-9*bloom,y:-12*bloom,width:18*bloom,height:16*bloom)
        c.fill(Path(ellipseIn:dome),with:.radialGradient(Gradient(colors:[Color(red:0.77,green:0.40,blue:0.15),Color(red:0.30,green:0.19,blue:0.11)]),center:CGPoint(x:-3,y:-8),startRadius:1,endRadius:13))
        for n in 0..<35 { let a=Double(n)*2.399, d=sqrt(Double(n)/35)*7*bloom; c.fill(Path(ellipseIn:CGRect(x:cos(a)*d,y:-4+sin(a)*d*0.7,width:1.2,height:1.7)),with:.color(.orange.opacity(0.75))) }; return
    }
    let petals = kind == 0 ? 21 : (kind == 1 ? 4 : (kind == 2 ? 8 : (kind == 4 ? 28 : (kind == 5 ? 16 : 15))))
    let layers = kind == 6 ? 5 : (kind == 4 || kind == 5 ? 2 : 1)
    for layer in 0..<layers {
        let rr = r*(1-Double(layer)*0.14)
        for n in 0..<petals {
            var p = c; p.rotate(by:.radians(Double(n)*2 * .pi/Double(petals)+Double(layer)*0.17))
            let irregular = 1+0.055*sin(Double(n)*7.13+Double(kind))
            let len = rr*irregular
            let w = len*(kind == 1 ? 0.94 : (kind == 2 ? 0.35 : (kind == 6 ? 0.26 : 0.14)))
            var petal = Path(); petal.move(to:CGPoint(x:-1,y:-2)); petal.addCurve(to:CGPoint(x:-w,y:-len*0.82),control1:CGPoint(x:-w*0.6,y:-len*0.3),control2:CGPoint(x:-w*1.1,y:-len*0.6))
            if kind == 5 {
                petal.addLines([CGPoint(x:-w*0.9,y:-len*1.07),CGPoint(x:-w*0.3,y:-len*0.92),CGPoint(x:0,y:-len*1.13),CGPoint(x:w*0.4,y:-len*0.95),CGPoint(x:w,y:-len*1.04)])
            } else { petal.addQuadCurve(to:CGPoint(x:w,y:-len*0.82),control:CGPoint(x:0,y:-len*(kind == 1 ? 1.2 : 1.08))) }
            petal.addCurve(to:CGPoint(x:1,y:-2),control1:CGPoint(x:w*1.1,y:-len*0.6),control2:CGPoint(x:w*0.5,y:-len*0.25)); petal.closeSubpath()
            p.fill(petal,with:.linearGradient(Gradient(colors:[colors[kind].opacity(0.95),colors[kind],Color(red:0.43,green:0.30,blue:0.17).opacity(0.65)]),startPoint:CGPoint(x:-w,y:-len),endPoint:CGPoint(x:0,y:3)))
            var vein = Path(); vein.move(to:CGPoint(x:0,y:-len*0.9)); vein.addQuadCurve(to:CGPoint(x:0,y:-5),control:CGPoint(x:1,y:-len*0.4)); p.stroke(vein,with:.color(.white.opacity(kind == 1 ? 0.16 : 0.22)),lineWidth:0.45)
        }
    }
    let core = r*(kind == 4 ? 0.43 : (kind == 1 ? 0.23 : (kind == 6 ? 0.12 : 0.22)))
    c.fill(Path(ellipseIn:CGRect(x:-core,y:-core*0.82,width:core*2,height:core*1.64)),with:.radialGradient(Gradient(colors:[kind == 4 || kind == 1 ? Color(red:0.43,green:0.29,blue:0.12) : Color(red:0.96,green:0.73,blue:0.24),Color(red:0.28,green:0.20,blue:0.10)]),center:CGPoint(x:-2,y:-2),startRadius:0,endRadius:core*1.4))
    for n in 0..<55 { let a=Double(n)*2.399, d=sqrt(Double(n)/55)*core*0.92; c.fill(Path(ellipseIn:CGRect(x:cos(a)*d,y:sin(a)*d*0.8,width:0.9,height:0.9)),with:.color(.yellow.opacity(0.55))) }
}

struct BloomPlacement { let tip: CGPoint; let growth: Double; let radius: Double }
func climateTemperature(season: String, hour: Double, snowfall: Double) -> Double {
    let baseline: Double = season == "winter" ? -5 : (season == "summer" ? 18 : (season == "spring" ? 7 : 4))
    let temperature=baseline+daylightAmount(hour)*9
    return snowfall > 0.02 ? min(-1,temperature) : temperature
}
func snowDepth(_ current: Double, seconds: Double, snowfall: Double, temperature: Double, exposed: Bool) -> Double {
    let accumulation=snowfall/(exposed ? 150.0 : 360.0)
    let melt=max(0,temperature)*(exposed ? 0.00020 : 0.00009)
    return min(1,max(0,current+seconds*(accumulation-melt)))
}
struct GroundSnow: View {
    let depth: Double
    var body: some View {
        Canvas { context,size in
            guard depth > 0.001 else { return }
            var blanket=Path();blanket.move(to:CGPoint(x:0,y:size.height))
            blanket.addLine(to:CGPoint(x:0,y:size.height*0.62))
            for n in 0...40 {
                let x=Double(n)/40*size.width
                let y=size.height*(0.60+sin(Double(n)*0.71)*0.013+cos(Double(n)*1.81)*0.009)
                blanket.addLine(to:CGPoint(x:x,y:y))
            }
            blanket.addLine(to:CGPoint(x:size.width,y:size.height));blanket.closeSubpath()
            context.fill(blanket,with:.linearGradient(Gradient(colors:[Color(red:0.84,green:0.88,blue:0.90).opacity(depth*0.45),Color(red:0.94,green:0.96,blue:0.97).opacity(depth*0.86)]),startPoint:CGPoint(x:0,y:size.height*0.6),endPoint:CGPoint(x:0,y:size.height)))
            for n in 0..<95 {
                let u=abs((sin(Double(n)*127.1)*43758.5453).truncatingRemainder(dividingBy:1))
                let v=abs((sin(Double(n)*311.7)*23421.631).truncatingRemainder(dividingBy:1))
                let r=(8+v*30)*sqrt(depth)
                let rect=CGRect(x:u*size.width-r,y:size.height*(0.60+v*0.4),width:r*2,height:r*0.27)
                context.fill(Path(ellipseIn:rect),with:.color(Color(red:0.96,green:0.98,blue:1).opacity(depth*(0.30+v*0.35))))
            }
        }.allowsHitTesting(false).accessibilityLabel("Ground snow: \(Int(depth*100)) percent")
    }
}
func drawSnowCap(_ context: GraphicsContext, at tip: CGPoint, kind: Int, radius: Double, bloom: Double, depth: Double) {
    guard depth > 0.005 && bloom > 0.08 else { return }
    let r=radius*bloom
    let snow=Color(red:0.96,green:0.98,blue:1)
    if kind == 3 {
        for tier in 0..<10 {
            let w=(4.5-Double(tier)*0.22)*depth
            context.fill(Path(ellipseIn:CGRect(x:tip.x-w,y:tip.y-Double(tier)*4.6*bloom-3,width:w*2,height:1.5+depth*2.2)),with:.color(snow.opacity(0.93)))
        }
    } else if kind == 9 {
        for n in 0..<5 {
            let x=tip.x+7+Double(n)*2,y=tip.y-Double(n)*8*bloom
            context.fill(Path(ellipseIn:CGRect(x:x-4*depth,y:y-2,width:9*depth,height:3*depth)),with:.color(snow))
        }
    } else {
        let top = kind == 7 ? -r*1.32 : (kind == 8 ? -12*bloom : -r*0.90)
        let width = (kind == 8 ? 9*bloom : r*(kind == 7 ? 0.68 : 0.82))*sqrt(depth)
        var cap=Path();cap.move(to:CGPoint(x:tip.x-width,y:tip.y+top+3))
        cap.addQuadCurve(to:CGPoint(x:tip.x+width,y:tip.y+top+3),control:CGPoint(x:tip.x,y:tip.y+top-7*depth))
        cap.addQuadCurve(to:CGPoint(x:tip.x-width,y:tip.y+top+3),control:CGPoint(x:tip.x,y:tip.y+top+3+7*depth));cap.closeSubpath()
        context.fill(cap,with:.linearGradient(Gradient(colors:[snow,Color(red:0.80,green:0.87,blue:0.91)]),startPoint:CGPoint(x:tip.x,y:tip.y+top-3),endPoint:CGPoint(x:tip.x,y:tip.y+top+7)))
    }
}

struct FlowerArt: View {
    let kind: Int
    let progress: Double
    let phase: Double
    var wind: Double = 0.2
    var snow: Double = 0
    var body: some View {
        Canvas { context, size in
            let habit = habits[kind]
            let maturity = min(1,log1p(max(0,progress-1))/2.5)
            let base = CGPoint(x:size.width/2,y:size.height-8)
            let height = 12+(habit.height-12)*min(1,progress*1.6)+26*maturity
            let sway = sin(phase)*(1+wind*5)
            let tip = CGPoint(x:base.x+sway,y:base.y-height)
            let green = kind == 3 ? Color(red:0.39,green:0.48,blue:0.36) : Color(red:0.28,green:0.40,blue:0.19)
            var heads = [BloomPlacement(tip:tip,growth:max(0,min(1,(progress-0.36)/0.64)),radius:(kind == 4 ? 27 : (kind == 1 ? 23 : 21))+maturity*4)]
            var stems: [(CGPoint,CGPoint,Double)] = [(base,tip,kind == 4 ? 3.5 : (kind == 3 ? 1.4 : 2))]
            for n in 0..<(habit.heads-1) {
                let growth = min(1,max(0,progress-Double(n)-1))
                if growth > 0 {
                    let side: Double = n % 2 == 0 ? -1 : 1
                    let fraction = Double(n/2+1)/Double((habit.heads+1)/2)
                    let root = habit.basal ? CGPoint(x:base.x+side*3,y:base.y-3) : CGPoint(x:base.x,y:base.y-height*(0.33+Double(n)*0.065))
                    let x = base.x+side*(habit.spread*(0.45+fraction*0.55))*growth+sway
                    let targetY = base.y-height*(habit.basal ? (0.78+0.12*sin(Double(n)*2)) : (0.67+0.12*sin(Double(n)*1.8)))
                    let end = CGPoint(x:x,y:root.y+(targetY-root.y)*growth)
                    stems.append((root,end,kind == 3 ? 1.2 : 1.6))
                    heads.append(.init(tip:end,growth:growth,radius:kind == 3 || kind == 9 ? 19 : (kind == 7 ? 20 : 15+maturity*3)))
                }
            }
            // Draw every stem first: younger shoots cannot overpaint older flowers.
            for (root,end,width) in stems {
                var stem = Path(); stem.move(to:root); stem.addCurve(to:end,control1:CGPoint(x:root.x+(end.x-root.x)*0.25,y:root.y-(root.y-end.y)*0.4),control2:CGPoint(x:end.x-2,y:end.y+20))
                context.stroke(stem,with:.color(green),style:StrokeStyle(lineWidth:width,lineCap:.round))
                var light = context; light.translateBy(x:-0.5,y:0); light.stroke(stem,with:.color(.white.opacity(0.12)),lineWidth:0.6)
            }
            // Species-specific foliage: blades, narrow paired leaves, or dissected fronds.
            let leaves = kind == 3 ? 12 : (kind == 7 || kind == 9 ? 5 : 6)
            for n in 0..<leaves {
                let side: Double = n % 2 == 0 ? -1 : 1
                let basal = kind == 3 || kind == 7 || kind == 9 || kind == 0
                let y = base.y-(basal ? Double(n/2)*5 : height*(0.16+Double(n)*0.095))
                let length = (kind == 7 || kind == 9 ? 65.0 : (kind == 3 ? 30 : 31))*min(1,progress*2)
                let root = CGPoint(x:base.x,y:y), end = CGPoint(x:base.x+side*length*(basal ? 0.50 : 0.85),y:y-length*(basal ? 0.95 : 0.55))
                let narrow = kind == 3 || kind == 9 || kind == 5
                let width = narrow ? 3.0 : (kind == 7 ? 12 : (kind == 4 ? 15 : 8))
                if kind == 2 || kind == 1 || kind == 6 {
                    var mid = Path(); mid.move(to:root); mid.addLine(to:end); context.stroke(mid,with:.color(green),lineWidth:1)
                    for k in 1..<6 { let f=Double(k)/6, at=CGPoint(x:root.x+(end.x-root.x)*f,y:root.y+(end.y-root.y)*f); for d in [-1.0,1] { var leaflet=Path(); leaflet.move(to:at); leaflet.addQuadCurve(to:CGPoint(x:at.x+side*9,y:at.y+d*(kind == 2 ? 8 : 5)-4),control:CGPoint(x:at.x+side*4,y:at.y+d*3)); context.stroke(leaflet,with:.color(green),style:StrokeStyle(lineWidth:kind == 2 ? 0.8 : 2.3,lineCap:.round)) } }
                } else {
                    var leaf=Path(); leaf.move(to:root); leaf.addQuadCurve(to:end,control:CGPoint(x:end.x-side*width,y:root.y-width)); leaf.addQuadCurve(to:root,control:CGPoint(x:root.x+side*width,y:end.y+width)); context.fill(leaf,with:.linearGradient(Gradient(colors:[green.opacity(0.95),Color(red:0.51,green:0.61,blue:0.34)]),startPoint:root,endPoint:end)); var vein=Path(); vein.move(to:root); vein.addLine(to:end); context.stroke(vein,with:.color(.white.opacity(0.18)),lineWidth:0.5)
                }
            }
            // Paint younger blooms first and the oldest bloom last.
            for head in heads.reversed() {
                drawHead(context,at:head.tip,kind:kind,bloom:head.growth,radius:head.radius)
                drawSnowCap(context,at:head.tip,kind:kind,radius:head.radius,bloom:head.growth,depth:snow)
            }
        }.frame(width:200,height:300)
    }
}

func daylightAmount(_ hour: Double) -> Double {
    let sun = cos((hour-12) * .pi / 12)
    let t = min(1,max(0,(sun+0.18)/0.95))
    return t*t*(3-2*t)
}
struct DaylightLayer: View {
    let hour: Double
    var body: some View {
        let day = daylightAmount(hour)
        let dusk = exp(-pow((hour-18.2)/1.5,2)) + exp(-pow((hour-5.8)/1.5,2))
        GeometryReader { geo in
            ZStack {
                Color(red:0.025,green:0.055,blue:0.18).opacity((1-day)*0.72)
                LinearGradient(colors:[Color(red:0.92,green:0.46,blue:0.25).opacity(dusk*0.24),.clear],startPoint:.top,endPoint:.bottom)
                Canvas { context,size in
                    for n in 0..<40 {
                        let x = (sin(Double(n)*127.1)*43758.5453).truncatingRemainder(dividingBy:1)
                        let y = (sin(Double(n)*311.7)*23421.631).truncatingRemainder(dividingBy:1)
                        let r = n % 4 == 0 ? 1.1 : 0.6
                        context.fill(Path(ellipseIn:CGRect(x:abs(x)*size.width,y:abs(y)*size.height*0.36,width:r*2,height:r*2)),with:.color(.init(red:0.87,green:0.91,blue:1).opacity(0.45+Double(n%5)*0.1)))
                    }
                }.opacity(pow(1-day,3)*0.7)
                Circle().fill(Color(red:0.87,green:0.90,blue:0.94)).frame(width:23,height:23).shadow(color:.white.opacity(0.3),radius:15).position(x:geo.size.width*0.77,y:geo.size.height*0.13).opacity(pow(1-day,4)*0.8)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

let seasonNames = ["winter", "spring", "summer", "autumn"]
func calendarSeason(month: Int, southern: Bool) -> String {
    let index = (month % 12)/3
    return seasonNames[(index+(southern ? 2 : 0))%4]
}
struct WeatherMix {
    var rain: Double = 0
    var wind: Double = 0.12
    var storm: Double = 0
    static func named(_ name: String) -> WeatherMix {
        switch name {
        case "rain", "snow": return .init(rain:0.65,wind:0.35)
        case "storm": return .init(rain:1,wind:0.9,storm:1)
        case "windy": return .init(wind:0.85)
        case "calm": return .init(wind:0.03)
        default: return .init()
        }
    }
    func blended(to next: WeatherMix, amount: Double) -> WeatherMix {
        let t=min(1,max(0,amount)); let a=t*t*(3-2*t)
        return .init(rain:rain+(next.rain-rain)*a,wind:wind+(next.wind-wind)*a,storm:storm+(next.storm-storm)*a)
    }
}
func automaticWeather(slot: Int, season: String) -> String {
    // Stable local simulation: no location lookup, forecast service or network.
    let hash = UInt64(bitPattern:Int64(slot)) &* 6364136223846793005 &+ 1442695040888963407
    let value = Int((hash >> 32)%100)
    let stormChance = season == "summer" ? 8 : (season == "winter" ? 1 : 4)
    if value < stormChance { return "storm" }
    if value < (season == "spring" || season == "autumn" ? 28 : 20) { return season == "winter" ? "snow" : "rain" }
    if value < 43 { return "windy" }
    if value < 72 { return "calm" }
    return "clear"
}
struct SeasonalTint: View {
    let season: String
    var body: some View {
        let color: Color = season == "autumn" ? .init(red:0.75,green:0.42,blue:0.12) : (season == "winter" ? .init(red:0.73,green:0.82,blue:0.89) : (season == "spring" ? .init(red:0.58,green:0.78,blue:0.33) : .init(red:0.87,green:0.76,blue:0.34)))
        color.opacity(season == "winter" ? 0.30 : (season == "autumn" ? 0.24 : 0.08)).blendMode(season == "winter" ? .screen : .softLight).allowsHitTesting(false)
    }
}
struct WeatherLayer: View {
    let mix: WeatherMix
    let time: Double
    let season: String
    let lightning: Bool
    let snow: Bool
    let strikes: [StormStrike]
    var body: some View {
        ZStack {
            Color(red:0.12,green:0.17,blue:0.22).opacity(mix.rain*0.19+mix.storm*0.10)
            Canvas { context,size in
                for n in 0..<150 {
                    let seed=Double(n)
                    if snow {
                        let depth=0.45+Double(n%7)/7
                        let x=(seed*73.13+time*12*depth+sin(time*0.45+seed)*18+mix.wind*20*sin(time*0.3)).truncatingRemainder(dividingBy:size.width+60)-30
                        let y=(seed*47.73+time*23*depth).truncatingRemainder(dividingBy:size.height+40)-20
                        let radius=1.1+depth*1.7
                        context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:radius*2,height:radius*2)),with:.color(.white.opacity(mix.rain*(0.35+depth*0.35))))
                        if n%11 == 0 {
                            var crystal=Path();crystal.move(to:CGPoint(x:x-2,y:y+radius));crystal.addLine(to:CGPoint(x:x+radius*2+2,y:y+radius));crystal.move(to:CGPoint(x:x+radius,y:y-2));crystal.addLine(to:CGPoint(x:x+radius,y:y+radius*2+2));context.stroke(crystal,with:.color(.white.opacity(mix.rain*0.4)),lineWidth:0.7)
                        }
                    } else {
                        let x=(seed*73.13+time*54+mix.wind*16*sin(time*0.3)).truncatingRemainder(dividingBy:size.width+60)-30
                        let y=(seed*47.73+time*310).truncatingRemainder(dividingBy:size.height+40)-20
                        var drop=Path();drop.move(to:CGPoint(x:x,y:y));drop.addLine(to:CGPoint(x:x+mix.wind*5,y:y+9+mix.storm*7))
                        context.stroke(drop,with:.color(.init(red:0.81,green:0.87,blue:0.93).opacity(mix.rain*0.38)),lineWidth:0.7)
                    }
                }
                // A few windborne leaves / winter flecks communicate gusts without clutter.
                for n in 0..<9 {
                    let seed=Double(n), width=size.width+50
                    let x=(seed*93+time*26+mix.wind*12*sin(time*0.4)).truncatingRemainder(dividingBy:width)-25
                    let y=size.height*(0.28+seed*0.065)+sin(time*0.6+seed)*16
                    var c=context;c.translateBy(x:x,y:y);c.rotate(by:.radians(time*0.7+seed))
                    let color: Color = season == "autumn" ? .init(red:0.76,green:0.43,blue:0.17) : (season == "winter" ? .white : .init(red:0.58,green:0.67,blue:0.29))
                    c.fill(Path(ellipseIn:CGRect(x:-3,y:-1.3,width:6,height:2.6)),with:.color(color.opacity(mix.wind*0.65)))
                }
                if lightning {
                    for strike in strikes {
                        let age=time-strike.occurredAt.timeIntervalSince1970
                        let pulse = age >= 0 ? exp(-age*7)*(1-exp(-age*60)) : 0
                        if pulse > 0.002 {
                            let glow=pulse*strike.strength
                            context.fill(Path(CGRect(origin:.zero,size:size)),with:.color(.init(red:0.80,green:0.87,blue:1).opacity(glow*0.22)))
                            var bolt=Path();var point=CGPoint(x:size.width*strike.x,y:0);bolt.move(to:point)
                            for step in 1...9 {
                                let next=CGPoint(x:size.width*strike.x+sin(strike.seed+Double(step)*8.3)*size.width*0.035,y:size.height*Double(step)*0.034)
                                bolt.addLine(to:next)
                                if step == 3 || step == 6 {
                                    var branch=Path();branch.move(to:next);branch.addLines([CGPoint(x:next.x+size.width*0.045,y:next.y+size.height*0.025),CGPoint(x:next.x+size.width*0.03,y:next.y+size.height*0.07)])
                                    context.stroke(branch,with:.color(.white.opacity(glow*0.6)),lineWidth:1)
                                }
                                point=next
                            }
                            context.stroke(bolt,with:.color(.init(red:0.63,green:0.77,blue:1).opacity(glow*0.3)),lineWidth:7)
                            context.stroke(bolt,with:.color(.white.opacity(glow)),lineWidth:1.8)
                        }
                    }
                }
            }
        }.allowsHitTesting(false).accessibilityLabel(mix.storm > 0.5 ? "Thunderstorm" : (mix.rain > 0.3 ? (snow ? "Snowfall" : "Rain") : (mix.wind > 0.6 ? "Windy weather" : "Calm weather")))
    }
}

func pollinatorActivity(_ hour: Double) -> Double {
    let t = min(1,max(0,(daylightAmount(hour)-0.08)/0.55))
    return t*t*(3-2*t)
}

struct WildlifeArt: View {
    let time: Double
    let age: Double
    let hour: Double
    var body: some View {
        let activity = pollinatorActivity(hour)
        Canvas { context, size in
            // Bees follow looping, uneven paths through the flower bed.
            for i in 0..<3 {
                let t = time*0.38+Double(i)*2.1
                let restX = size.width*(0.19+Double(i)*0.29)
                let restY = size.height*(0.84+Double(i%2)*0.05)
                let x = restX + (size.width*(0.5+0.31*sin(t))-restX)*activity
                let y = restY + (size.height*(0.52+0.13*sin(t*1.7+Double(i)))-restY)*activity
                var c = context; c.translateBy(x:x,y:y); c.scaleBy(x:activity > 0.05 ? beeFacing(t) : 1,y:1); c.rotate(by:.radians(cos(t)*0.2*beeFacing(t)*activity))
                let wing = 2+activity*(2+abs(sin(time*24+Double(i)))*5)
                for d in [-1.0,1] { c.fill(Path(ellipseIn:CGRect(x:d*3-4,y:-wing-3,width:8,height:wing)),with:.color(.white.opacity(0.7))) }
                c.fill(Path(ellipseIn:CGRect(x:-8,y:-4,width:16,height:9)),with:.color(Color(red:0.96,green:0.72,blue:0.22)))
                for n in [-3.0,2] { c.stroke(Path(CGRect(x:n,y:-3,width:1.2,height:7)),with:.color(.black.opacity(0.7)),lineWidth:1.5) }
                c.fill(Path(ellipseIn:CGRect(x:6,y:-3,width:5,height:6)),with:.color(Color(red:0.19,green:0.20,blue:0.13)))
            }
            // Staggered generations keep every part of metamorphosis present.
            for i in 0..<3 {
                let clock = age+Double(i)*800
                let stage = lifeStage(clock)
                let origin = CGPoint(x:size.width*(0.25+Double(i)*0.24),y:size.height*(0.79+Double(i%2)*0.08))
                if stage == 0 {
                    let x = origin.x + sin(time*0.12+Double(i))*24
                    for n in 0..<7 {
                        let y = origin.y+sin(time*2-Double(n)*0.8)*1.8
                        context.fill(Path(ellipseIn:CGRect(x:x+Double(n)*4,y:y,width:7,height:7)),with:.color(Color(red:0.62-Double(n)*0.025,green:0.74,blue:0.32)))
                        var leg = Path(); leg.move(to:CGPoint(x:x+Double(n)*4+3,y:y+5)); leg.addLine(to:CGPoint(x:x+Double(n)*4+2,y:y+9)); context.stroke(leg,with:.color(ink),lineWidth:0.8)
                    }
                    context.fill(Path(ellipseIn:CGRect(x:x+28,y:origin.y+1,width:2,height:2)),with:.color(ink))
                } else if stage == 1 {
                    var twig = Path(); twig.move(to:CGPoint(x:origin.x-20,y:origin.y+17)); twig.addQuadCurve(to:CGPoint(x:origin.x+8,y:origin.y-27),control:CGPoint(x:origin.x-25,y:origin.y-20)); context.stroke(twig,with:.color(Color(red:0.36,green:0.40,blue:0.21)),lineWidth:2)
                    let x = origin.x+sin(time*0.7)*1.2
                    var silk = Path(); silk.move(to:CGPoint(x:origin.x+8,y:origin.y-27)); silk.addLine(to:CGPoint(x:x+8,y:origin.y-20)); context.stroke(silk,with:.color(.white.opacity(0.6)),lineWidth:0.7)
                    context.fill(Path(ellipseIn:CGRect(x:x,y:origin.y-21,width:15,height:27)),with:.linearGradient(Gradient(colors:[Color(red:0.77,green:0.81,blue:0.47),Color(red:0.36,green:0.49,blue:0.23)]),startPoint:CGPoint(x:x,y:origin.y-21),endPoint:CGPoint(x:x+15,y:origin.y+6)))
                    for n in 0..<4 { var seam = Path(); seam.move(to:CGPoint(x:x+2,y:origin.y-14+Double(n)*4)); seam.addLine(to:CGPoint(x:x+12,y:origin.y-12+Double(n)*4)); context.stroke(seam,with:.color(.white.opacity(0.3)),lineWidth:0.7) }
                } else {
                    let resting = CGPoint(x:size.width*(0.23+Double(i)*0.26),y:size.height*(0.72+Double(i%2)*0.08))
                    let flying = CGPoint(x:size.width*(0.5+0.34*sin(time*0.22+Double(i)*2)),y:size.height*(0.35+0.16*cos(time*0.31+Double(i))))
                    let position = CGPoint(x:resting.x+(flying.x-resting.x)*activity,y:resting.y+(flying.y-resting.y)*activity)
                    drawButterfly(context,at:position,time:time+Double(i),variant:i,activity:activity)
                }
            }
        }.allowsHitTesting(false).accessibilityLabel(activity == 0 ? "Sleeping bees and butterflies; caterpillars and cocoons" : "Active bees and butterflies; caterpillars and cocoons")
    }
    func drawButterfly(_ context: GraphicsContext, at point: CGPoint, time: Double, variant: Int, activity: Double) {
        var c = context; c.translateBy(x:point.x,y:point.y); c.rotate(by:.radians(sin(time*0.8)*0.3*activity))
        let flap = 0.12+activity*(0.18+0.7*abs(sin(time*5)))
        let color: Color = variant == 0 ? .init(red:0.95,green:0.66,blue:0.28) : (variant == 1 ? .init(red:0.53,green:0.73,blue:0.93) : .init(red:0.91,green:0.75,blue:0.95))
        for side in [-1.0,1] {
            var wing = c; wing.scaleBy(x:side*flap,y:1)
            for (y,w,h) in [(-15.0,18.0,20.0),(0.0,13.0,14.0)] {
                let shape = Path(ellipseIn:CGRect(x:1,y:y,width:w,height:h)); wing.fill(shape,with:.color(color)); wing.stroke(shape,with:.color(ink.opacity(0.8)),lineWidth:1.5)
                wing.fill(Path(ellipseIn:CGRect(x:w*0.5,y:y+5,width:4,height:5)),with:.color(.white.opacity(0.8)))
            }
        }
        c.fill(Path(ellipseIn:CGRect(x:-1.8,y:-9,width:3.6,height:22)),with:.color(ink))
        for side in [-1.0,1] { var antenna = Path(); antenna.move(to:CGPoint(x:0,y:-8)); antenna.addQuadCurve(to:CGPoint(x:side*5,y:-17),control:CGPoint(x:side*2,y:-16)); c.stroke(antenna,with:.color(ink),lineWidth:0.8) }
    }
}

struct GardenView: View {
    @ObservedObject var garden: Garden
    @State private var confirmingReset = false
    var body: some View {
        GeometryReader { geo in
            ZStack {
                scene(geo.size)
                if garden.showControls {
                    VStack(spacing:0) {
                        header.padding(.top,garden.immersive ? 0 : 20)
                        Spacer(minLength:0)
                        controls
                    }.transition(.opacity)
                }
            }.animation(.easeInOut(duration:0.35),value:garden.showControls)
            .onContinuousHover { phase in
                garden.surfaceSize = geo.size
                switch phase { case .active(let point): garden.pointer = point; case .ended: garden.pointer = nil }
                garden.trackEdge()
            }
        }.frame(minWidth:560,minHeight:540).foregroundStyle(ink).preferredColorScheme(.light)
        .sheet(isPresented:$garden.settings) { settingsView }

    }
    func scene(_ size: CGSize) -> some View {
        ZStack {
            if let image = NSImage(named:"garden") { Image(nsImage:image).resizable().scaledToFill().frame(width:size.width,height:size.height).clipped() }
            SeasonalTint(season:garden.season(at:garden.now))
            LinearGradient(colors:[.black.opacity(0.08),.clear,.black.opacity(0.08)],startPoint:.top,endPoint:.bottom).allowsHitTesting(false)
            Color.clear.contentShape(Rectangle())
                .onTapGesture { p in garden.plant(at:p,in:size) }

            TimelineView(.animation(minimumInterval:1/60,paused:garden.hidden)) { timeline in
                ZStack {
                GroundSnow(depth:garden.state.groundSnow ?? 0)
                ZStack {
                    ForEach(garden.state.flowers.sorted(by:{$0.y < $1.y})) { f in
                        FlowerArt(kind:f.kind,progress:f.age/growTimes[f.kind],phase:timeline.date.timeIntervalSinceReferenceDate*0.8+f.x*20,wind:garden.weather(at:timeline.date).wind,snow:f.snow ?? 0)
                            .background(alignment:.bottom) { if garden.selected == f.id && garden.showControls { Ellipse().stroke(.white.opacity(0.8),lineWidth:1).frame(width:44,height:12) } }
                            .position(x:f.x*size.width,y:f.y*size.height-142)
                            .onTapGesture { if garden.showControls && garden.planting == nil { garden.selected = f.id; garden.lastEdge = Date() } }
                            .accessibilityLabel("\(names[f.kind]), \(Int(min(1,f.age/growTimes[f.kind])*100)) percent bloomed, \(headCount(f.age,f.kind)) heads")
                    }
                }.allowsHitTesting(garden.planting == nil)
                WildlifeArt(time:timeline.date.timeIntervalSinceReferenceDate,age:garden.state.wildlifeAge ?? 0,hour:garden.displayHour(at:timeline.date))
                DaylightLayer(hour:garden.displayHour(at:timeline.date))
                WeatherLayer(mix:garden.weather(at:timeline.date),time:timeline.date.timeIntervalSince1970,season:garden.season(at:timeline.date),lightning:garden.state.lightningEnabled ?? true,snow:snowing(season:garden.season(at:timeline.date),weather:garden.weatherName(at:timeline.date)),strikes:garden.strikes)
                }.frame(width:size.width,height:size.height)
            }
            if garden.planting != nil {
                Text("Click the moss to plant your \(names[garden.planting!].lowercased()).").font(.system(size:18,design:.serif)).foregroundStyle(.white).shadow(radius:5).padding(12).background(ink.opacity(0.6),in:Capsule()).position(x:size.width/2,y:120).allowsHitTesting(false)
            }
        }.clipped()
        .simultaneousGesture(SpatialTapGesture(count:3).onEnded { event in
            if event.location.y < size.height*0.42 { garden.godMode = true; garden.settings = true }
        })
    }
    var header: some View {
        HStack(spacing:14) {
            Image(systemName:"leaf.fill").font(.title2)
            VStack(alignment:.leading,spacing:2) { Text("Stillgarden").font(.system(size:24,weight:.medium,design:.serif)); Text("A SMALL WORLD, ALWAYS GROWING").font(.system(size:8,weight:.semibold)).tracking(1.5) }
            Spacer()
            Button { garden.toggleSound() } label: { Image(systemName:garden.soundOn ? "speaker.wave.2" : "speaker.slash") }.help(garden.soundOn ? "Mute ambient audio" : "Unmute ambient audio")
            Button { garden.state.gardenOnly = !garden.immersive; garden.controlsVisible = true; garden.lastEdge = Date(); garden.updateChrome(); garden.save() } label: { Image(systemName:garden.immersive ? "rectangle.dashed" : "rectangle.inset.filled") }.help(garden.immersive ? "Keep controls visible" : "Garden only — hover an edge for controls")
            Button { garden.state.pinned.toggle(); garden.pin() } label: { Image(systemName:garden.state.pinned ? "pin.fill" : "pin") }.help("Keep garden above other apps")
            Button { garden.rest() } label: { Image(systemName:"moon") }.help("Fade away")
            Button { garden.settings = true } label: { Image(systemName:"slider.horizontal.3") }.help("Garden settings")
        }.buttonStyle(.borderless).padding(.horizontal,20).padding(.vertical,18).background(.regularMaterial)
    }
    var controls: some View {
        VStack(spacing:10) {
            if let f = garden.state.flowers.first(where:{$0.id == garden.selected}) {
                HStack {
                    VStack(alignment:.leading,spacing:3) {
                        Text(names[f.kind]).font(.system(size:15,weight:.semibold,design:.serif))
                        Text(f.age >= growTimes[f.kind] ? "\(headCount(f.age,f.kind)) heads · still growing" : "\(Int(f.age/growTimes[f.kind]*100))% grown · \(Int(ceil((growTimes[f.kind]-f.age)/60))) garden min to bloom").font(.system(size:10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("+10 min") { garden.boost(bloom:false) }
                    Button("Bloom") { garden.boost(bloom:true) }
                    Button { if let i = garden.state.flowers.firstIndex(where:{$0.id == f.id}) { garden.state.flowers[i].age += growTimes[f.kind]; garden.save() } } label: { Image(systemName:"leaf.arrow.triangle.circlepath") }.help("Grow another branching cycle")
                    Button { garden.state.flowers.removeAll(where:{$0.id == f.id}); garden.selected = nil; garden.save() } label: { Image(systemName:"trash") }.help("Remove this flower")
                }
            } else {
                HStack { Text("Life moves at its own pace.").font(.system(size:15,design:.serif)); Spacer(); Text("\(garden.state.flowers.count) plants · choose a seed").font(.system(size:10)).foregroundStyle(.secondary) }
            }
            LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:6),count:5),spacing:6) {
                ForEach(0..<names.count,id:\.self) { i in
                    Button { garden.planting = garden.planting == i ? nil : i; garden.selected = nil } label: {
                        HStack(spacing:5) { Circle().fill(colors[i]).frame(width:9,height:9).overlay(Circle().stroke(ink.opacity(0.2))); Text(names[i]).font(.system(size:10,weight:.medium)) }.frame(maxWidth:.infinity).padding(.vertical,8).background(garden.planting == i ? ink.opacity(0.2) : Color.white.opacity(0.65)).clipShape(RoundedRectangle(cornerRadius:8))
                    }.buttonStyle(.plain).help("\(Int(growTimes[i]/60)) garden minutes to first bloom")
                }
            }
            HStack {
                Image(systemName:"clock"); Text("Growth").font(.system(size:11))
                Picker("Growth speed",selection:$garden.state.speed) { Text("Paused").tag(0.0); Text("1×").tag(1.0); Text("5×").tag(5.0); Text("30×").tag(30.0); Text("120×").tag(120.0) }.labelsHidden().frame(width:100).onChange(of:garden.state.speed) { _ in garden.save() }
                Spacer()
                Text(garden.immersive ? "Hover an edge for controls" : (garden.state.pinned ? "Pinned above your apps" : "Unpinned")).font(.system(size:10)).foregroundStyle(.secondary)
                if garden.planting != nil { Button("Cancel") { garden.planting = nil } }
            }
        }.padding(16).background(.regularMaterial)
    }
    var settingsView: some View {
        ScrollView { VStack(alignment:.leading,spacing:18) {
            Text(garden.godMode ? "God mode" : "A gentler rhythm").font(.system(size:27,design:.serif))
            Toggle("Garden only · reveal controls at the edge",isOn:Binding(get:{garden.immersive},set:{garden.state.gardenOnly = $0; garden.updateChrome(); garden.save()}))
            Toggle("Nature sounds",isOn:Binding(get:{garden.soundOn},set:{garden.state.soundEnabled = $0; garden.updateAudio(); garden.save()}))
            HStack { Text("Volume"); Slider(value:Binding(get:{garden.state.volume ?? 0.22},set:{garden.state.volume = $0; garden.updateAudio()}),in:0...1); Text("\(Int((garden.state.volume ?? 0.22)*100))%").font(.system(size:11)).frame(width:35) }
            Divider()
            Text("Day & night").font(.system(size:16,weight:.medium,design:.serif))
            Picker("Lighting",selection:Binding(get:{garden.state.daylightMode ?? "system"},set:{garden.setDayMode($0)})) {
                Text("Mac clock").tag("system"); Text("Manual").tag("manual"); Text("Cycle").tag("cycle")
            }.pickerStyle(.segmented)
            if (garden.state.daylightMode ?? "system") != "system" {
                HStack {
                    Text("Time")
                    Slider(value:Binding(get:{garden.state.cycleHour ?? 12},set:{garden.setManualHour($0)}),in:0...23.999)
                    Text(String(format:"%02d:%02d",Int(garden.state.cycleHour ?? 12),Int(((garden.state.cycleHour ?? 12).truncatingRemainder(dividingBy:1))*60))).monospacedDigit().frame(width:48)
                }
            } else { Text("Follows your Mac’s local time continuously.").font(.system(size:11)).foregroundStyle(.secondary) }
            if garden.state.daylightMode == "cycle" {
                Picker("Cycle speed",selection:Binding(get:{garden.state.daySpeed ?? 60},set:{garden.tick(); garden.state.daySpeed = $0; garden.save()})) {
                    Text("1× · 24 hours/day").tag(1.0)
                    Text("60× · 24 minutes/day").tag(60.0)
                    Text("240× · 6 minutes/day").tag(240.0)
                    Text("1440× · 1 minute/day").tag(1440.0)
                }
            }
            Divider()
            Text("Weather & seasons").font(.system(size:16,weight:.medium,design:.serif))
            Picker("Weather",selection:Binding(get:{garden.state.weatherMode ?? "auto"},set:{garden.setWeather($0)})) {
                Text("Automatic · occasional changes").tag("auto")
                Text("Clear").tag("clear"); Text("Calm wind").tag("calm"); Text("Windy").tag("windy")
                Text("Rain / winter snow").tag("rain"); Text("Snow").tag("snow"); Text("Thunderstorm").tag("storm")
            }
            Text("Now: \(garden.weatherName(at:garden.now).capitalized) · \(garden.season(at:garden.now).capitalized)").font(.system(size:11)).foregroundStyle(.secondary)
            Toggle("Lightning",isOn:Binding(get:{garden.state.lightningEnabled ?? true},set:{garden.state.lightningEnabled=$0; garden.save()}))
            Picker("Season",selection:Binding(get:{garden.state.seasonMode ?? "calendar"},set:{garden.state.seasonMode=$0; garden.updateAudio(); garden.save()})) {
                Text("Mac calendar").tag("calendar")
                ForEach(["spring","summer","autumn","winter"],id:\.self) { Text($0.capitalized).tag($0) }
            }
            Toggle("Southern hemisphere seasons",isOn:Binding(get:{garden.state.southernHemisphere ?? false},set:{garden.state.southernHemisphere=$0; garden.updateAudio(); garden.save()}))
            Text("Weather is a local garden simulation. Winter precipitation falls as snow. Each lightning strike has its own delayed thunder. Triple-click open sky to enter God mode.").font(.system(size:11)).foregroundStyle(.secondary)
            if garden.godMode {
                if garden.weatherName(at:garden.now) == "storm" {
                    Button("Lightning now") { garden.strikes.append(.random(at:Date())) }
                }
                HStack { Button("Grow all +1 hour") { for i in garden.state.flowers.indices { garden.state.flowers[i].age += 3600 }; garden.save() }; Button("Advance wildlife") { garden.state.wildlifeAge = (garden.state.wildlifeAge ?? 0)+800; garden.save() } }
            }
            Divider()
            Text("Garden care").font(.system(size:16,weight:.medium,design:.serif))
            Text("Ground snow: \(Int((garden.state.groundSnow ?? 0)*100))% · builds during snowfall and melts gradually in warmth. Snow continues changing while the app is closed.").font(.system(size:11)).foregroundStyle(.secondary)
            HStack {
                Button("Reset garden…",role:.destructive) { confirmingReset=true }
                if garden.resetBackup != nil { Button("Undo last reset") { garden.undoGardenReset() } }
            }
            Text(garden.message).font(.system(size:11)).foregroundStyle(.secondary)
            Divider()
            Link("Made with care by Paradoxical Software ↗",destination:URL(string:"https://paradoxicalsw.com")!).font(.system(size:13,weight:.medium))
            Text("A free, open-source labor of love. A little room to breathe.").font(.system(size:11)).foregroundStyle(.secondary)
            Divider()
            Toggle("Automatic garden visits",isOn:$garden.state.reminders)
            HStack { Text("Time between visits"); Spacer(); Picker("Interval",selection:$garden.state.interval) { ForEach([1.0,5,10,15,30,60],id:\.self) { Text("\(Int($0)) minutes").tag($0) } }.labelsHidden().frame(width:140) }
            HStack { Text("Stay visible for"); Spacer(); Picker("Duration",selection:$garden.state.duration) { ForEach([15.0,30,45,60,120,300],id:\.self) { Text("\(Int($0)) seconds").tag($0) } }.labelsHidden().frame(width:140) }
            Text("Bees and butterflies rest at night and wake gradually at dawn. Caterpillars become cocoons, then butterflies, on the garden clock. Flowers develop species-specific stems, foliage and new blooms after their first flowering. Audio rests when the garden is hidden.").font(.system(size:11)).foregroundStyle(.secondary)
            HStack { Button("Preview fade") { garden.settings = false; garden.state.reminders = true; garden.rest(); garden.nextReveal = Date().addingTimeInterval(5); garden.save() }; Spacer(); Button("Done") { garden.settings = false; garden.godMode = false; garden.lastEdge = Date(); garden.configureReminders() }.keyboardShortcut(.defaultAction) }
        }.padding(28) }.frame(width:480,height:680).foregroundStyle(ink).preferredColorScheme(.light)
        .confirmationDialog("Reset this garden?",isPresented:$confirmingReset,titleVisibility:.visible) {
            Button("Reset garden",role:.destructive) { garden.resetGarden() }
            Button("Cancel",role:.cancel) { }
        } message: { Text("Remove all plants and accumulated snow, and restart wildlife. Your settings stay the same. You can undo this reset, even after reopening the app.") }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let garden = Garden()
    var window: NSWindow!
    var status: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu(); let root = NSMenuItem(); menu.addItem(root); let appMenu = NSMenu(); root.submenu = appMenu
        appMenu.addItem(withTitle:"About Stillgarden",action:#selector(about),keyEquivalent:"")
        appMenu.addItem(withTitle:"Show Garden",action:#selector(show),keyEquivalent:"g")
        appMenu.addItem(withTitle:"Paradoxical Software Website",action:#selector(website),keyEquivalent:"")
        appMenu.addItem(.separator()); appMenu.addItem(withTitle:"Quit Stillgarden",action:#selector(quit),keyEquivalent:"q"); NSApp.mainMenu = menu
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:640,height:620),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.title = "Stillgarden"; window.titleVisibility = .hidden; window.titlebarAppearsTransparent = true
        window.contentView = NSHostingView(rootView:GardenView(garden:garden).ignoresSafeArea()); window.backgroundColor = NSColor(calibratedRed:0.96,green:0.95,blue:0.90,alpha:1)
        window.minSize = NSSize(width:560,height:580); window.setFrameAutosaveName("StillgardenWindow"); window.center(); window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]; garden.window = window; garden.pin()
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
        status = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength); status.button?.image = NSImage(systemSymbolName:"leaf",accessibilityDescription:"Stillgarden")
        let statusMenu = NSMenu(); statusMenu.addItem(withTitle:"Show Garden",action:#selector(show),keyEquivalent:""); statusMenu.addItem(withTitle:"Fade Garden",action:#selector(hide),keyEquivalent:""); statusMenu.addItem(withTitle:"Mute / Unmute",action:#selector(sound),keyEquivalent:""); statusMenu.addItem(withTitle:"Show / Hide Controls",action:#selector(chrome),keyEquivalent:""); statusMenu.addItem(.separator()); statusMenu.addItem(withTitle:"Quit Stillgarden",action:#selector(quit),keyEquivalent:""); status.menu = statusMenu
        garden.configureReminders(); garden.startExperience()
    }
    @objc func website() { NSWorkspace.shared.open(URL(string:"https://paradoxicalsw.com")!) }
    @objc func about() { NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Stillgarden",.applicationVersion:"1.1.0",.credits:NSAttributedString(string:"A small garden for your desktop.\nA labor of love by Paradoxical Software.\nhttps://paradoxicalsw.com")]) }
    @objc func show() { garden.reveal(); if garden.state.reminders { garden.hideAt = Date().addingTimeInterval(garden.state.duration) } }
    @objc func sound() { garden.toggleSound() }
    @objc func chrome() { garden.state.gardenOnly = !garden.immersive; garden.controlsVisible = true; garden.updateChrome(); garden.save() }
    @objc func hide() { garden.rest() }
    @objc func quit() { garden.save(); NSApp.terminate(nil) }
    func windowShouldClose(_ sender:NSWindow) -> Bool { garden.rest(); return false }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool) -> Bool { show(); return true }
    func applicationWillTerminate(_ notification:Notification) { garden.save() }
}

if CommandLine.arguments.contains("--render-demo") {
    // Render the real interface with a staged garden, never the user's save.
    let app = NSApplication.shared
    MainActor.assumeIsolated {
        let args=CommandLine.arguments
        guard let index=args.firstIndex(of:"--render-demo"),args.count > index+2 else { fatalError("Usage: --render-demo day|night|winter|controls output.png") }
        let scene=args[index+1], path=args[index+2]
        let scratch=FileManager.default.temporaryDirectory.appendingPathComponent("Stillgarden-demo-"+UUID().uuidString).appendingPathComponent("garden.json")
        let garden=Garden(saveURL:scratch,startTimer:false)
        garden.state=GardenState(flowers:[
            Flower(kind:0,x:0.19,y:0.81,age:3600),Flower(kind:3,x:0.38,y:0.75,age:12000),
            Flower(kind:2,x:0.57,y:0.82,age:7500),Flower(kind:4,x:0.76,y:0.77,age:9000),
            Flower(kind:7,x:0.33,y:0.94,age:4400),Flower(kind:5,x:0.69,y:0.96,age:4800)])
        garden.state.daylightMode="manual";garden.state.cycleHour=scene == "night" ? 23 : 12
        garden.state.seasonMode=scene == "winter" ? "winter" : "summer"
        garden.state.weatherMode=scene == "winter" ? "snow" : "clear"
        garden.state.groundSnow=scene == "winter" ? 0.65 : 0
        garden.state.wildlifeAge=160
        if scene == "winter" { for i in garden.state.flowers.indices { garden.state.flowers[i].snow=0.7 } }
        garden.state.gardenOnly=true;garden.controlsVisible=scene == "controls"
        let renderer=ImageRenderer(content:GardenView(garden:garden).frame(width:640,height:620))
        renderer.scale=2
        guard let cg=renderer.cgImage else { fatalError("Could not render demo") }
        let bitmap=NSBitmapImageRep(cgImage:cg)
        try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
    }
} else if CommandLine.arguments.contains("--self-test") {
    let g = Garden(); g.timer?.invalidate()
    g.state = GardenState(flowers:[Flower(kind:0,x:0.5,y:0.8,age:0)],speed:5)
    g.advance(60); precondition(g.state.flowers[0].age == 300)
    g.state.speed = 0; g.advance(100); precondition(g.state.flowers[0].age == 300)
    g.selected = g.state.flowers[0].id
    // Test arithmetic without writing a user's save.
    g.state.speed = 120; g.advance(100); precondition(g.state.flowers[0].age == 12300)
    let data = try! JSONEncoder().encode(g.state); let restored = try! JSONDecoder().decode(GardenState.self,from:data); precondition(restored.flowers.count == 1 && restored.flowers[0].age == 12300)
    let legacy = "{\"flowers\":[],\"speed\":1,\"pinned\":true,\"reminders\":false,\"interval\":15,\"duration\":45,\"savedAt\":0}"
    let old = try! JSONDecoder().decode(GardenState.self,from:Data(legacy.utf8)); precondition(old.gardenOnly == nil && old.soundEnabled == nil)
    precondition(g.state.wildlifeAge == 12300)
    precondition(headCount(1200,0) == 1 && headCount(3600,0) == 3 && headCount(999999,0) == 5)
    precondition(names.count == growTimes.count && colors.count == names.count)
    precondition(lifeStage(0) == 0 && lifeStage(900) == 1 && lifeStage(1600) == 2 && lifeStage(2400) == 0)
    g.audioStarted = true; g.state.weatherMode = "storm"; g.state.soundEnabled = false
    g.nextStrikeAt = Date(timeIntervalSince1970:100)
    g.updateOneShots(at:Date(timeIntervalSince1970:100))
    precondition(g.strikes.count == 1 && !g.strikes[0].thunderPlayed)
    g.updateOneShots(at:Date(timeIntervalSince1970:109))
    precondition(g.strikes[0].thunderPlayed)
    g.hidden = true;g.updateOneShots(at:Date(timeIntervalSince1970:110))
    precondition(g.strikes.isEmpty && g.nextStrikeAt == nil)
    g.hidden = false;g.audioStarted = false
    precondition(snowDepth(0,seconds:120,snowfall:0.65,temperature:-2,exposed:true) > 0.5)
    precondition(snowDepth(0.8,seconds:300,snowfall:0,temperature:-3,exposed:false) == 0.8)
    precondition(snowDepth(0.8,seconds:300,snowfall:0,temperature:20,exposed:true) == 0)
    precondition(climateTemperature(season:"summer",hour:12,snowfall:0) > climateTemperature(season:"winter",hour:0,snowfall:0))
    let testDir=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("work/snow-reset-test-"+UUID().uuidString)
    try! FileManager.default.createDirectory(at:testDir,withIntermediateDirectories:true)
    let testURL=testDir.appendingPathComponent("garden.json")
    let isolated=Garden(saveURL:testURL,startTimer:false)
    isolated.state=GardenState(flowers:[Flower(kind:3,x:0.5,y:0.8,age:3000)],speed:5)
    isolated.state.weatherMode="snow";isolated.state.seasonMode="winter";isolated.state.daylightMode="manual";isolated.state.cycleHour=0
    isolated.advanceSnow(120,endingAt:Date())
    let initialSnow=isolated.state.groundSnow ?? 0
    precondition(initialSnow > 0.2 && (isolated.state.flowers[0].snow ?? 0) > initialSnow)
    isolated.state.weatherMode="clear";isolated.advanceSnow(120,endingAt:Date());precondition(isolated.state.groundSnow == initialSnow)
    isolated.save()
    let reopened=Garden(saveURL:testURL,startTimer:false)
    precondition(abs((reopened.state.groundSnow ?? 0)-initialSnow)<0.001)
    reopened.resetGarden();precondition(reopened.state.flowers.isEmpty && reopened.state.groundSnow == 0 && reopened.state.speed == 5)
    let afterReset=Garden(saveURL:testURL,startTimer:false)
    precondition(afterReset.resetBackup != nil && afterReset.state.flowers.isEmpty)
    afterReset.undoGardenReset();precondition(afterReset.state.flowers.count == 1 && afterReset.state.groundSnow == initialSnow)
    afterReset.state.seasonMode="summer";afterReset.advanceSnow(30,endingAt:Date())
    precondition((afterReset.state.groundSnow ?? 0) < initialSnow && (afterReset.state.groundSnow ?? 0) > 0)
    afterReset.advanceSnow(3600,endingAt:Date());precondition(afterReset.state.groundSnow == 0 && afterReset.state.flowers[0].snow == 0)
    try! FileManager.default.removeItem(at:testDir)
    let randomStrikes=(0..<100).map { _ in StormStrike.random(at:Date(timeIntervalSince1970:100)) }
    precondition(randomStrikes.allSatisfy { (1.8...8.5).contains($0.delay) && $0.thunderAt > $0.occurredAt })
    precondition(Set(randomStrikes.map { $0.variant }).count == 3)
    precondition(Set(randomStrikes.map { $0.delay }).count > 95)
    precondition(snowing(season:"winter",weather:"rain") && snowing(season:"summer",weather:"snow") && !snowing(season:"summer",weather:"rain"))
    precondition(Set((0..<1000).map { automaticWeather(slot:$0,season:"winter") }).contains("snow"))
    precondition(calendarSeason(month:10,southern:false) == "autumn" && calendarSeason(month:10,southern:true) == "spring")
    precondition(calendarSeason(month:12,southern:false) == "winter" && calendarSeason(month:3,southern:false) == "spring")
    let weatherMid = WeatherMix.named("calm").blended(to:.named("storm"),amount:0.5)
    precondition(weatherMid.rain == 0.5 && weatherMid.storm == 0.5)
    let seen = Set((0..<1000).map { automaticWeather(slot:$0,season:"summer") })
    precondition(seen == Set(["clear","calm","windy","rain","storm"]))
    precondition(pollinatorActivity(0) == 0 && pollinatorActivity(22) == 0 && pollinatorActivity(12) == 1)
    precondition(pollinatorActivity(6) > 0 && pollinatorActivity(6) < pollinatorActivity(8))
    precondition(abs(pollinatorActivity(6.001)-pollinatorActivity(5.999)) < 0.001)
    precondition(beeFacing(0) == 1 && beeFacing(.pi) == -1)
    precondition(habits[3].height > habits[0].height && habits[7].basal && habits[7].heads == 3)
    precondition(daylightAmount(12) > 0.99 && daylightAmount(0) == 0)
    precondition(abs(daylightAmount(5.999)-daylightAmount(6.001)) < 0.001)
    g.state.daylightMode = "cycle"; g.state.cycleHour = 23; g.state.daySpeed = 60; g.advance(120)
    precondition(abs((g.state.cycleHour ?? 0)-1) < 0.00001)
    g.state.daylightMode = "manual"; g.advance(3600); precondition(g.state.cycleHour == 1)
    print("PASS: snow accumulation, cold retention, warm melt, persistence, reset and undo after reopening, random strike delays and thunder variants, winter snow, calendar seasons, weather distribution and blending, nighttime sleep, gradual dawn activity, bee facing, botanical habits, smooth daylight, day cycle wrap, manual clock, growth beyond bloom, time scaling, pause, persistence, v1 save migration, wildlife lifecycle, flower catalog")
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate(); app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
}
