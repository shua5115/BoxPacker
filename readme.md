# Box Packer

A small application which attempts to fit rectangles into an enclosure in the most compact way possible.
It uses a greedy algorithm which first sorts boxes by area, then chooses the best next available spot for a box.

## Features
* Boxes can be marked as "can rotate", and the program tries different rotations to find the best fit
* Length units can be specified (in, cm, ft, mm, etc.)

## Shortcomings
The box packing problem this program attempts to solve is NP-complete,
which means it is not (currently?) possible to solve optimally in "polynomial time".

This program can often find decent packings if there is ample free space,
but if the enclosure just barely fits all the boxes, the program is less likely to succeed.