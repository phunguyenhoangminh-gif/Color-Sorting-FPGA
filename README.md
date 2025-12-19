# FPGA Color Sorting System on Arty Z7-20

## 1. Introduction
This project implements an automated **Color Sorting System** using the **Xilinx Arty Z7-20** FPGA development board. The system identifies objects based on color (Red/Green) using a **TCS3200** sensor and sorts them into different paths using **SG90 Servo Motors**.

### Key Features:
* **High-Speed Processing:** Utilizing FPGA parallel processing capabilities.
* **Robust Sensing:** Custom Verilog driver for TCS3200 with **Auto-Exposure/Long-Range** configuration.
* **Queue Management (FIFO):** Implemented a **FIFO Buffer** to handle multiple objects on the conveyor belt simultaneously without synchronization errors.
* **Configurable Actuators:** Servo drivers with adjustable **Start Delay** and **Hold Time** parameters.

## 2. Hardware Architecture

### Components:
* **Controller:** Digilent Arty Z7-20 (Zynq-7000 SoC).
* **Color Sensor:** TCS3200 (RGB Color Sensor).
* **Object Detection:** IR Obstacle Avoidance Sensors (x1).
* **Actuators:** SG90 Micro Servos (x2).

### Wiring Guide (Pmod Interface):

| Component | Signal | Arty Z7 Pin | Pmod Port |
| :--- | :--- | :--- | :--- |
| **TCS3200** | S0, S1, S2, S3 | Y18, Y19, Y16, Y17 | JA [1-4] |
| | OUT | U18 | JA [7] |
| **IR Sensor** | OUT | W14 | JB [1] |
| **Servo 1** (Red) | PWM | Y14 | JB [2] |
| **Servo 2** (Green)| PWM | T11 | JB [3] |

*> Note: Servos must be powered by an external 5V source or the VU pin on the Arty board, not the 3.3V Pmod VCC.*

## 3. System Logic Flow

1.  **Color Detection:** The TCS3200 sensor continuously samples color data. A stable filtering algorithm determines if the object is **RED** or **GREEN**.
2.  **FIFO Queuing:**
    * When a valid color is detected, it is pushed into a **FIFO Queue**.
    * This allows multiple objects to pass the color sensor before reaching the sorting area.
3.  **Sorting Trigger:**
    * The IR sensor at the end of the conveyor detects the object's arrival.
    * The system pops the color data from the FIFO Queue.
4.  **Actuation:**
    * **If RED:** Servo 1 activates immediately, holds for 1s, then returns.
    * **If GREEN:** Servo 2 waits for 4s (travel time), activates, holds for 4s, then returns.

## 4. How to Run

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/your-username/ArtyZ7-Color-Sorting.git](https://github.com/your-username/ArtyZ7-Color-Sorting.git)
    ```
2.  **Open Vivado:**
    * Create a new RTL Project targeting `xc7z020clg400-1`.
    * Add `rtl/sorting_system.v` as Design Source.
    * Add `constrs/Arty-Z7-20-Master.xdc` as Constraints.
3.  **Build:**
    * Run Synthesis -> Implementation -> Generate Bitstream.
4.  **Deploy:**
    * Open Hardware Manager -> Auto Connect -> Program Device.

## 5. License
Open Source Project.