version 4.7.1

class sts_EventHandler : EventHandler
{
  override void worldTick()
  {
    for (let position = Left; position < PositionsCount; ++position)
      mSounds[position] = None;

    if (players[consolePlayer].mo == NULL) return;

    if (mIsInitialized)
      mIterator.reinit();
    else
      initialize();

    int maxDistance = mMaxDistanceCvar.getInt();
    int maxDistanceSquared = maxDistance * maxDistance;

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
        if (anActor.distance2DSquared(player) > maxDistanceSquared) continue;

        let type = (anActor.bIsMonster || anActor.bMissile) ? Danger : Ambient;
        let position = calculateActorScreenPosition(anActor);
        mSounds[position] = max(mSounds[position], type);

        if (mSounds[Left] == Danger && mSounds[Center] == Danger && mSounds[Right] == Danger)
          break;

        continue;
      }

      let aMover = Mover(aThinker);
      if (aMover != NULL)
      {
        Sector aSector = aMover.getSector();
        vector3 playerRelative = player.posRelative(aSector);
        vector2 diff = aSector.centerSpot - playerRelative.xy;
        if (diff.length() > maxDistance) continue;
        let position = calculateSectorScreenPosition(aSector);
        mSounds[position] = max(mSounds[position], Geometry);
      }
    }
  }

  override void renderOverlay(RenderEvent event)
  {
    if (!mIsInitialized) return;
    if (players[consolePlayer].mo == NULL) return;

    double xDistance = mXDistanceCvar.getFloat();
    double leftPosition  = SCREEN_CENTER - xDistance;
    double rightPosition = SCREEN_CENTER + xDistance;

    if (mSounds[Left])   renderText(Left,   leftPosition,  "STS_LEFT_SOUND");
    if (mSounds[Center]) renderText(Center, SCREEN_CENTER, "STS_CENTER_SOUND");
    if (mSounds[Right])  renderText(Right,  rightPosition, "STS_RIGHT_SOUND");
  }

  private ui void renderText(ScreenPosition screenPosition, double xPosition, string text)
  {
    text = StringTable.localize(text, false);
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
    mScaleCvar       = Cvar.getCvar("sts_scale", player);
    mXDistanceCvar   = Cvar.getCvar("sts_x_distance", player);
    mYPositionCvar   = Cvar.getCvar("sts_y_position", player);
    mMaxDistanceCvar = Cvar.getCvar("sts_max_distance", player);

    mColors[None]     = Font.CR_WHITE;
    mColors[Ambient]  = Font.CR_WHITE;
    mColors[Geometry] = Font.CR_GREEN;
    mColors[Danger]   = Font.CR_RED;
  }

  enum SoundType {None, Ambient, Geometry, Danger, SoundTypesCount}
  enum ScreenPosition {Left, Center, Right, PositionsCount}
  const MARGIN = 5;
  const SCREEN_CENTER = 0.5;

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

  private SoundType mSounds[PositionsCount];
  private int mColors[SoundTypesCount];
  private transient bool mIsInitialized;
  private transient ThinkerIterator mIterator;

  private transient Cvar mScaleCvar;
  private transient Cvar mXDistanceCvar;
  private transient Cvar mYPositionCvar;
  private transient Cvar mMaxDistanceCvar;
}
