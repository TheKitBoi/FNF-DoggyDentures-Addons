package;

import lime.media.openal.ALFilter;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxBasic;
import flixel.tweens.FlxTween;
import flixel.system.FlxSound;
#if desktop
import haxe.io.Bytes;
import lime.utils.UInt8Array;
import lime.media.vorbis.VorbisFile;
import lime.media.openal.AL;
import lime.media.vorbis.VorbisInfo;
#end

class AudioThing extends FlxBasic
{
	//DD: Ripped from my drums mod
	//DD: OpenAL doesn't work on HTML5, so fallback to FlxG.sound when on web
	#if desktop
	var vorb:VorbisFile;
	var _length:Float;
	var _volume:Float = 1.0;
	var audioSource = AL.createSource();
	var audioBuffer = AL.createBuffer();
	var audioAux = AL.createAux();
	var audioEffect = AL.createEffect();
	var audioFilter = AL.createFilter();
	#else
	var elseSound:FlxSound;
	#end

	public var fadeTween:FlxTween;

	public var volume(get, set):Float;
	public var time(get, set):Float;
	public var speed(get, set):Float;
	public var playing(get, never):Bool;
	public var stopped(get, never):Bool;
	public var length(get, never):Float;
	var _lostFocus:Bool = false;

	public var lostFocus(get, never):Bool;

	public override function new(filePath:String)
	{
		#if desktop
		// DD: Use OpenAL manually for music to allow for speed change
		audioSource = AL.createSource();
		audioBuffer = AL.createBuffer();
		if (sys.FileSystem.exists(filePath))
		{
			vorb = VorbisFile.fromFile(filePath);
		}
		else
			return;
		var sndData = SyllableSound.readVorbisFileBuffer(vorb);
		var vorbInfo:VorbisInfo = vorb.info();
		var vorbChannels = AL.FORMAT_STEREO16;
		if (vorbInfo.channels <= 1)
			vorbChannels = AL.FORMAT_MONO16;
		var vorbRate = vorbInfo.rate;
		_length = vorb.timeTotal() * 1000;
		AL.bufferData(audioBuffer, vorbChannels, sndData, sndData.length, vorbRate);
		AL.sourcei(audioSource, AL.BUFFER, audioBuffer);
		
		if (TitleState.pitchShift && Conductor.playbackSpeed != 1.0)
		{
			#if (!hl)
			//DD: wtf why doesn't this work on hl?
			var rawPitchShiftOffset:Float = -(12*Math.log(Conductor.playbackSpeed) / Math.log(2));
			var newSemitone:Int = Math.floor(rawPitchShiftOffset);
			var newCents:Int = Std.int(Math.min(Math.floor((rawPitchShiftOffset - newSemitone) * 100), 50));
			AL.sourcei(audioSource, AL.AUXILIARY_SEND_FILTER_GAIN_AUTO, 1);
			AL.sourcei(audioSource, AL.AUXILIARY_SEND_FILTER_GAINHF_AUTO, 1);
			AL.effecti(audioEffect, AL.EFFECT_TYPE, AL.EFFECT_PITCH_SHIFTER);
			AL.effecti(audioEffect, AL.PITCH_SHIFTER_COARSE_TUNE, newSemitone);
			AL.effecti(audioEffect, AL.PITCH_SHIFTER_FINE_TUNE, newCents);
			AL.auxi(audioAux, AL.EFFECTSLOT_EFFECT, audioEffect);
			AL.source3i(audioSource, AL.AUXILIARY_SEND_FILTER, audioAux, 0, 0);
			AL.filteri(audioFilter, AL.FILTER_TYPE, AL.FILTER_LOWPASS);
			AL.filterf(audioFilter, AL.LOWPASS_GAIN, 0);
			AL.filterf(audioFilter, AL.LOWPASS_GAINHF, 0);
			AL.sourcei(audioSource, AL.DIRECT_FILTER, audioFilter);
			#end
		}
		#else
		elseSound = new FlxSound().loadEmbedded(filePath);
		#end
		super();
	}

	public override function destroy()
	{
		AL.deleteSource(audioSource);
		AL.deleteBuffer(audioBuffer);
		super.destroy();
	}

	public override function update(elapsed:Float):Void
	{
		#if desktop
		if (audioSource != null)
		{
			if (FlxG.sound.muted)
				AL.sourcef(audioSource, AL.GAIN, 0);
			else
				AL.sourcef(audioSource, AL.GAIN, _volume * FlxG.sound.volume);
		}
		#end
		super.update(elapsed);
	}

	//public var onComplete:Void->Void;

	public function play()
	{
		#if desktop
		if (audioSource != null)
			AL.sourcePlay(audioSource);
		#else
		elseSound.play();
		#end
		
	}

	public function pause()
	{
		#if desktop
		if (audioSource != null)
			AL.sourcePause(audioSource);
		#else
		elseSound.pause();
		#end
	}

	public function stop()
	{
		#if desktop
		if (audioSource != null)
			AL.sourceStop(audioSource);
		#else
		elseSound.stop();
		#end
	}

	public inline function muteAfterTimeElapsed(Duration:Float = 1):Void
	{
		if (fadeTween != null)
			fadeTween.cancel();
		fadeTween = FlxTween.num(1, 1, Duration, {onComplete: function(_){volume = 0;}});

		return;
	}

	inline function get_playing():Bool
	{
		#if desktop
		if (audioSource != null)
			return (AL.getSourcei(audioSource, AL.SOURCE_STATE) == AL.PLAYING);
		#else
		return elseSound.playing;
		#end
		return false;
	}

	inline function get_stopped():Bool
		{
			#if desktop
			if (audioSource != null)
				return (AL.getSourcei(audioSource, AL.SOURCE_STATE) == AL.STOPPED);
			#else
			return !elseSound.playing;
			#end
			return false;
		}

	inline function get_length():Float
	{
		#if desktop
		if (audioSource != null)
			return _length;
		#else
		return elseSound.length;
		#end
		return 0;
	}

	inline function get_volume():Float
	{
		#if desktop
		if (audioSource != null)
			return _volume;
		#else
		return elseSound.volume;
		#end
		return 0;
	}

	inline function set_volume(newVol:Float):Float
	{
		#if desktop
		if (audioSource != null)
			_volume = newVol;
		#else
		elseSound.volume = newVol;
		#end
		return newVol;
	}

	inline function get_time():Float
	{
		#if desktop
		if (audioSource != null)
			return AL.getSourcef(audioSource, AL.SEC_OFFSET) * 1000;
		#else
		return elseSound.length;
		#end
		return 0;
	}

	function set_time(newTime:Float):Float
	{
		#if desktop
		if (audioSource != null)
			AL.sourcef(audioSource, AL.SEC_OFFSET, newTime/1000);
		#else
		elseSound.time = newTime;
		#end
		return newTime;
	}

	inline function get_speed():Float
	{
		#if desktop
		if (audioSource != null)
			return AL.getSourcef(audioSource, AL.PITCH);
		#else
		return 1.0;
		#end
		return 0;
	}

	function set_speed(newSpeed:Float):Float
	{
		#if desktop
		if (audioSource != null)
		{
			AL.sourcef(audioSource, AL.PITCH, newSpeed);
			
		}
		return newSpeed;
		#end
		return 1.0;
	}

	inline function get_lostFocus():Bool
	{
		return _lostFocus;
	}

	public function loseFocus()
	{
		_lostFocus = true;
		pause();
	}

	public function regainFocus()
	{
		_lostFocus = false;
		play();
	}
}
