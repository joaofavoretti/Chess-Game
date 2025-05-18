const std = @import("std");
const rl = @import("raylib");
const MoveType = @import("move.zig").MoveType;

const SOUND_ASSET_PATH = "./assets/sounds";

pub const SoundType = enum {
    MoveSelf,
    MoveOpponent,
    Capture,
    Castle,
    GameEnd,
    GameStart,
    Promote,
    Check,
};

pub const SoundSystem = struct {
    moveSelfSound: rl.Sound,
    moveOpponentSound: rl.Sound,
    captureSound: rl.Sound,
    castleSound: rl.Sound,
    gameEndSound: rl.Sound,
    gameStartSound: rl.Sound,
    checkSound: rl.Sound,
    promoteSound: rl.Sound,

    pub fn init() !SoundSystem {
        return SoundSystem{
            .moveSelfSound = try rl.loadSound(SOUND_ASSET_PATH ++ "/move-self.mp3"),
            .moveOpponentSound = try rl.loadSound(SOUND_ASSET_PATH ++ "/move-opponent.mp3"),
            .captureSound = try rl.loadSound(SOUND_ASSET_PATH ++ "/capture.mp3"),
            .castleSound = try rl.loadSound(SOUND_ASSET_PATH ++ "/castle.mp3"),
            .gameEndSound = try rl.loadSound(SOUND_ASSET_PATH ++ "/game-end.mp3"),
            .gameStartSound = try rl.loadSound(SOUND_ASSET_PATH ++ "/game-start.mp3"),
            .checkSound = try rl.loadSound(SOUND_ASSET_PATH ++ "/move-check.mp3"),
            .promoteSound = try rl.loadSound(SOUND_ASSET_PATH ++ "/promote.mp3"),
        };
    }

    pub fn playSound(self: *SoundSystem, soundType: SoundType) void {
        switch (soundType) {
            SoundType.MoveSelf => rl.playSound(self.moveSelfSound),
            SoundType.MoveOpponent => rl.playSound(self.moveOpponentSound),
            SoundType.Capture => rl.playSound(self.captureSound),
            SoundType.Castle => rl.playSound(self.castleSound),
            SoundType.GameEnd => rl.playSound(self.gameEndSound),
            SoundType.GameStart => rl.playSound(self.gameStartSound),
            SoundType.Promote => rl.playSound(self.promoteSound),
            SoundType.Check => rl.playSound(self.checkSound),
        }
    }

    pub fn deinit(self: *SoundSystem) void {
        rl.unloadSound(self.moveSelfSound);
        rl.unloadSound(self.moveOpponentSound);
        rl.unloadSound(self.captureSound);
        rl.unloadSound(self.castleSound);
        rl.unloadSound(self.gameEndSound);
        rl.unloadSound(self.gameStartSound);
        rl.unloadSound(self.promoteSound);
        rl.unloadSound(self.checkSound);
    }
};
