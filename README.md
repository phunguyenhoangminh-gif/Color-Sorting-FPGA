# FPGA Color Sorting System with Start-Delay Logic

## 1. Introduction
This project implements an automated **Color Sorting System** using the **Xilinx Arty Z7-20** FPGA. The system identifies objects based on color (Red/Green) using a **TCS3200** sensor and sorts them using two **SG90 Servo Motors**.

This version features a single IR sensor for object detection and configurable **Start Delays** for each servo, allowing for precise timing control based on the conveyor belt speed.

### Key Features:
* **Controller:** Digilent Arty Z7-20 (Zynq-7000 SoC).
* **Sensor Fusion:** Combines TCS3200 Color Sensor (Long Range Mode) and IR Obstacle Sensor.
* **Precise Actuation:**
    * **Servo Angle:** Calibrated to **60 degrees**.
    * **Timing Control:** Individual `START_DELAY` and `HOLD_TIME` for each servo channel.
* **Manual Override:** Dedicated buttons to test each servo manually.

## 2. Hardware Architecture

### Pin Mapping (Arty Z7-20 Pmod)

| Component | Signal | Arty Pin | Pmod Port | Description |
| :--- | :--- | :--- | :--- | :--- |
| **System** | CLK | H16 | - | 125MHz Clock |
| | RST | D19 | BTN0 | System Reset (Active High) |
| **Manual** | BTN1 | D20 | BTN1 | Test Servo 1 |
| | BTN2 | L20 | BTN2 | Test Servo 2 |
| **TCS3200** | S0, S1 | Y18, Y19 | JA [1-2] | Scaling Select |
| | S2, S3 | Y16, Y17 | JA [3-4] | Filter Select |
| | OUT | U18 | JA [7] | Frequency Output |
| **IR Sensor**| OUT | W14 | JB [1] | Object Detection (Active Low) |
| **Servo 1** | PWM | Y14 | JB [2] | Sorts **RED** objects |
| **Servo 2** | PWM | T11 | JB [3] | Sorts **GREEN** objects |

*> **Note:** Servos must be powered by an external 5V source (or the VU pin), do not use the 3.3V Pmod VCC.*

## 3. System Configuration (Current Firmware)

The system is configured with the following parameters in `top_module.v`:

### Color Sensor (TCS3200)
* **Mode:** Long Range / High Sensitivity.
* **Scaling:** 100% (S0=1, S1=1).
* **Sampling Time:** 100ms.

### Servo Actuators (SG90)
* **Target Angle:** **60 Degrees** (Pulse width: ~1.17ms).
* **Servo 1 (RED Channel):**
    * **Trigger Condition:** RED Color + IR Sensor active.
    * **Start Delay:** `2.1 seconds` (262,500,000 cycles).
    * **Hold Time:** `0.24 seconds` (30,000,000 cycles).
* **Servo 2 (GREEN Channel):**
    * **Trigger Condition:** GREEN Color + IR Sensor active.
    * **Start Delay:** `4.0 seconds` (500,000,000 cycles).
    * **Hold Time:** `0.24 seconds` (30,000,000 cycles).

## 4. How It Works

1.  **Color Recognition:** The TCS3200 continuously scans for objects. If a dominant color (Red or Green) is detected, it is stored in memory.
2.  **Object Detection:** When the object reaches the single IR sensor (connected to Pmod JB1), the system checks the stored color.
3.  **Timed Sorting:**
    * If **RED**: Servo 1 waits for its programmed delay (2.1s), then kicks the object (60°).
    * If **GREEN**: Servo 2 waits for its programmed delay (4.0s), then kicks the object (60°).
    * *The delay accounts for the travel time from the IR sensor to the specific servo location on the conveyor.*

## 5. Setup & Usage

1.  **Bitstream Generation:** Open project in Vivado 2018.2, Run Synthesis, Implementation, and Generate Bitstream.
2.  **Calibration:**
    * Place an object in front of the TCS3200. Ensure the RGB LEDs on the Arty board reflect the detected color (Red or Green).
    * Adjust the potentiometer on the IR sensor until the `LD3` LED lights up when an object is present.
3.  **Testing:**
    * Press **BTN1** to manually trigger Servo 1.
    * Press **BTN2** to manually trigger Servo 2.
    * Run objects on the conveyor belt to test automatic sorting.

## 6. License
Open Source Project.
