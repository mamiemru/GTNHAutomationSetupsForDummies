
Setup:

Purple are output, Cyan inputs.


<img width="990" height="758" alt="image" src="https://github.com/user-attachments/assets/9ed0e130-96c2-4785-8ceb-24857bd48322" />


## Controller config:
Cover is on the right side in strong mode (Soldering alloy to side) sent to the red alloy cable.

<img width="754" height="496" alt="image" src="https://github.com/user-attachments/assets/fb9b26a9-03cd-4a8a-a794-32e975a3c009" />


## Helium plasma feed (Right side):

Cyan provide Helium Plasma from the interface, The IV pump pump from the interface into the lv fluid tank.
Only One volumetric flask is set to 100mb. Input hatch is ZPM. 

Ender item conduit: 
- from Tank to hatch: Insert green, Extract green Active with signal.
- from hatch to tank: Insert green, Extract green Active without signal.

<img width="1146" height="890" alt="image" src="https://github.com/user-attachments/assets/8074b933-6621-436c-a1b7-cec78bb327b7" />


## Super Coolant feed (Left side):

Cyan provide Super coolant from the interface, The IV pump pump from the interface into the lv fluid tank.
Only One volumetric flask is set to 2000mb. Input hatch is ZPM.

Ender item conduit:
- from Tank to hatch: Insert green, Extract green Active with signal.
- from hatch to tank: Insert green, Extract green Active without signal.

<img width="1254" height="814" alt="image" src="https://github.com/user-attachments/assets/339134a9-33f4-45f8-bd9d-f2130e984f44" />

## Logic:

From left to right: Alloy cable, Not gate, repeater 1tick, pulse former, State cell (13sec, 23sec, 13, 23, 13, 23)
The cable on on the top linked to Helium, the cable bottom linked to coolant.

<img width="1938" height="597" alt="image" src="https://github.com/user-attachments/assets/8b815aa2-543e-48af-89c2-d90d784b8b1e" />
