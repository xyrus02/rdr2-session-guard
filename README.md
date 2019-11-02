# GTA V Session Guard
This utility allows you to split your GTA Online session into a new one without any players. 
It makes it easier to complete delivery missions without griefers and modders harrassing you.

It also contains an experimental feature which prevents other players from connecting to your
session. This probably won't work as Rockstar keeps breaking it with patches. The split feature
should always work, however.

## How to use
Run the tool as admin, then press SHIFT + PAUSE to clear your session. The game will freeze for
about 10 seconds. Use SHIFT + SCROLL LOCK to lock / unlock your session from joiners.

## How does it work
The session split works by momentarily halting the GTA V process completely. This will cause a 
timeout which will kick you from the active session. When the process continues, you will be
reconnected to the GTA V servers but since you are ejected from your previous session, your
game will open a new one and joins this one.

For everybody else, this looks like you just dropped (which is the case). From your perspective,
everybody in your previous session seems to have left at the same time.

The lockdown feature works by blocking the network traffic on ports the UDP ports GTA V uses to
communicate with the servers. Since these appear to be dynamic, it likely won't work. Better
ideas are welcome!
