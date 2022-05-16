/* Copyright Alexander Kromm (mmaulwurff@gmail.com) 2022
 *
 * This file is part of Sound to Screen.
 *
 * Sound to Screen is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * Sound to Screen is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * Sound to Screen. If not, see <https://www.gnu.org/licenses/>.
 */

version 4.7.1

class sts_EventHandler : EventHandler
{
  /**
   * Fills mSounds array by searching for actors that make sounds and
   * doors/elevators.
   */
  override void worldTick()
  {
    for (let position = Left; position < PositionsCount; ++position)
    {
      mSounds[position] = None;
      mMinDistance[position] = int.max;
    }

    if (players[consolePlayer].mo == NULL) return;

    if (mIsInitialized)
      mIterator.reinit();
    else
      initialize();

    int maxDistance = mMaxDistanceCvar.getInt();
    bool noiseEnabled = mNoiseEnabledCvar.getInt();

    let player = players[consolePlayer].mo;
    Thinker aThinker;
    while (aThinker = mIterator.next())
    {
      let anActor = Actor(aThinker);
      if (anActor != NULL)
      {
        if (anActor == player) continue;
        if (anActor is "Inventory" && Inventory(anActor).owner != NULL) continue;
        if (!anActor.isActorPlayingSound(CHAN_AUTO)) continue;
        int distance = int(anActor.distance2D(player)) / DISTANCE_UNIT;
        if (distance > maxDistance) continue;

        let type = ((anActor.bIsMonster && !anActor.bFriendly)
                    || (anActor.bMissile && anActor.damage > 0)) ? Danger : Noise;
        if (type == Noise && !noiseEnabled) continue;
        let position = calculateActorScreenPosition(anActor);
        mSounds[position] = max(mSounds[position], type);

        if (mSounds[position] == type)
          mMinDistance[position] = min(mMinDistance[position], distance);

        if (mSounds[Left] == Danger && mSounds[Center] == Danger && mSounds[Right] == Danger)
          break;

        continue;
      }

      let aMover = Mover(aThinker);
      if (aMover != NULL)
      {
        Sector movingSector = aMover.getSector();
        vector3 playerRelative = player.posRelative(movingSector);
        vector2 diff = movingSector.centerSpot - playerRelative.xy;
        int distance = int(diff.length()) / DISTANCE_UNIT;
        if (distance > maxDistance) continue;

        let position = calculateSectorScreenPosition(movingSector);
        mSounds[position] = max(mSounds[position], Geometry);

        if (mSounds[position] == Geometry)
          mMinDistance[position] = min(mMinDistance[position], distance);
      }
    }
  }

  /**
   * Displays mSounds array contents on the screen.
   */
  override void renderOverlay(RenderEvent event)
  {
    if (!mIsInitialized) return;
    if (players[consolePlayer].mo == NULL) return;

    double xDistance = mXDistanceCvar.getFloat();
    double leftPosition  = SCREEN_CENTER - xDistance;
    double rightPosition = SCREEN_CENTER + xDistance;

    mColors[Noise]    = mColorNoiseCvar.getInt();
    mColors[Geometry] = mColorGeometryCvar.getInt();
    mColors[Danger]   = mColorDangerCvar.getInt();

    if (mSounds[Left])   renderText(Left,   leftPosition,  "STS_LEFT_SOUND");
    if (mSounds[Center]) renderText(Center, SCREEN_CENTER, "STS_CENTER_SOUND");
    if (mSounds[Right])  renderText(Right,  rightPosition, "STS_RIGHT_SOUND");
  }

  private ui void renderText(ScreenPosition screenPosition, double xPosition, string text)
  {
    text = mShowDistanceCvar.getInt()
      ? String.format("%d", mMinDistance[screenPosition])
      : StringTable.localize(text, false);
    Font aFont = NewSmallFont;
    int scale = mScaleCvar.getInt();
    int textWidth  = scale * aFont.stringWidth(text);
    int textHeight = scale * aFont.getHeight();
    int screenWidth  = Screen.getWidth();
    int screenHeight = Screen.getHeight();
    int scaledMargin = MARGIN * scale;
    int x = clamp(int(xPosition * screenWidth) - textWidth / 2,
                  scaledMargin, screenWidth - textWidth - scaledMargin);
    int y = clamp(int(mYPositionCvar.getFloat() * screenHeight),
                  scaledMargin, screenHeight - textHeight - scaledMargin);
    int textColor = mColors[mSounds[screenPosition]];
    Color backgroundColor = StringTable.localize("$STS_BACKGROUND_COLOR");

    Screen.dim(backgroundColor, 0.5,
               x - scaledMargin, y - scaledMargin,
               textWidth + 2 * scaledMargin, textHeight + 2 * scaledMargin);
    Screen.drawText(aFont, textColor, x, y, text, DTA_ScaleX, scale, DTA_ScaleY, scale);
  }

  private void initialize()
  {
    mIsInitialized = true;
    mIterator = ThinkerIterator.create("Thinker");

    PlayerInfo player = players[consolePlayer];
    mScaleCvar        = Cvar.getCvar("sts_scale", player);
    mXDistanceCvar    = Cvar.getCvar("sts_x_distance", player);
    mYPositionCvar    = Cvar.getCvar("sts_y_position", player);
    mShowDistanceCvar = Cvar.getCvar("sts_show_distance", player);

    mMaxDistanceCvar  = Cvar.getCvar("sts_max_distance2", player);
    mNoiseEnabledCvar = Cvar.getCvar("sts_noise_enabled", player);

    mColorNoiseCvar    = Cvar.getCvar("sts_color_noise", player);
    mColorGeometryCvar = Cvar.getCvar("sts_color_geometry", player);
    mColorDangerCvar   = Cvar.getCvar("sts_color_danger", player);
  }

  private static ScreenPosition calculateActorScreenPosition(Actor target)
  {
    PlayerInfo player = players[consolePlayer];
    double angleToTarget = (player.mo.angleTo(target) - player.mo.angle) % 360.0 - 180.0;

    if (abs(angleToTarget) > (180 - player.fov / 2))
      return Center;

    return (angleToTarget < 0.0) ? Left : Right;
  }

  private static ScreenPosition calculateSectorScreenPosition(sector aSector)
  {
    PlayerInfo player = players[consolePlayer];
    vector3 playerRelative = player.mo.posRelative(aSector);
    vector2 diff = aSector.centerSpot - playerRelative.xy;
    double angleToTarget = (atan2(diff.y, diff.x) - player.mo.angle) % 360.0 - 180.0;

    if (abs(angleToTarget) > (180 - player.fov / 2))
      return Center;

    return (angleToTarget < 0.0) ? Left : Right;
  }

  enum SoundType {None, Noise, Geometry, Danger, SoundTypesCount}
  enum ScreenPosition {Left, Center, Right, PositionsCount}
  const MARGIN = 5;
  const SCREEN_CENTER = 0.5;
  const DISTANCE_UNIT = 32;

  private SoundType mSounds[PositionsCount];
  private int mMinDistance[PositionsCount];
  private ui int mColors[SoundTypesCount];
  private transient bool mIsInitialized;
  private transient ThinkerIterator mIterator;

  private transient Cvar mScaleCvar;
  private transient Cvar mXDistanceCvar;
  private transient Cvar mYPositionCvar;
  private transient Cvar mShowDistanceCvar;

  private transient Cvar mMaxDistanceCvar;
  private transient Cvar mNoiseEnabledCvar;

  private transient Cvar mColorNoiseCvar;
  private transient Cvar mColorGeometryCvar;
  private transient Cvar mColorDangerCvar;
}
