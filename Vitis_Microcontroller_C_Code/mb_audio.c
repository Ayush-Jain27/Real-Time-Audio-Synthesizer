/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "xparameters.h"
#include "sleep.h"

//Including that GPIO type shi

#ifndef XPAR_GPIO_STATUS_DEVICE_ID
    #define GPIO_STATUS_ID  XPAR_AXI_GPIO_0_DEVICE_ID // Input: Switches
#else
    #define GPIO_STATUS_ID  XPAR_GPIO_STATUS_DEVICE_ID
#endif

#ifndef XPAR_GPIO_VOLUME_DEVICE_ID
    #define GPIO_VOLUME_ID  XPAR_AXI_GPIO_1_DEVICE_ID // Input: Volume from Audio
#else
    #define GPIO_VOLUME_ID  XPAR_GPIO_VOLUME_DEVICE_ID
#endif

#ifndef XPAR_GPIO_GFX_DEVICE_ID
    #define GPIO_GFX_ID     XPAR_AXI_GPIO_2_DEVICE_ID // Output: Bar Height to HDMI
#else
    #define GPIO_GFX_ID     XPAR_GPIO_GFX_DEVICE_ID
#endif
// ===========================================================================

// GPIO Instances
XGpio Gpio_Status, Gpio_Volume, Gpio_Gfx;

int main()
{
    init_platform();
    xil_printf("\n\r=== Audio Visualizer Started ===\n\r");

    int Status;

    // Initialize Status GPIO (Switches)
    Status = XGpio_Initialize(&Gpio_Status, GPIO_STATUS_ID);
    if (Status != XST_SUCCESS) xil_printf("Error: Status GPIO Init Failed\n\r");

    // Initialize Volume GPIO (From Audio Looper)
    Status = XGpio_Initialize(&Gpio_Volume, GPIO_VOLUME_ID);
    if (Status != XST_SUCCESS) xil_printf("Error: Volume GPIO Init Failed\n\r");

    // Initialize Graphics GPIO (To Color Mapper)
    Status = XGpio_Initialize(&Gpio_Gfx, GPIO_GFX_ID);
    if (Status != XST_SUCCESS) xil_printf("Error: Gfx GPIO Init Failed\n\r");

    // 1 = Input, 0 = Output

    XGpio_SetDataDirection(&Gpio_Status, 1, 0xFFFFFFFF); // All Inputs
    XGpio_SetDataDirection(&Gpio_Volume, 1, 0xFFFFFFFF); // All Inputs
    XGpio_SetDataDirection(&Gpio_Gfx, 1, 0x00000000);    // All Outputs

    xil_printf("Hardware Initialized. Starting Visualizer Loop...\n\r");

    u32 volume_raw;
    u32 bar_height;

    u32 peak_height = 0;
    u32 gravity_counter = 0;


    while (1) {
        //Read raw volume from Hardware (16-bit value: 0 to 32768)
        volume_raw = XGpio_DiscreteRead(&Gpio_Volume, 1);


        // The screen bar area is about 400 pixels tall.
        // scale 32,000 down to 400.
        // Shifting right by 6 divides by 64. (32000 / 64 = 500), which is close enough.
        bar_height = volume_raw >> 3;

        //Clip to max height
        // This prevents the green bar from drawing over the "REC" icon at the top
        if (bar_height > 400) bar_height = 400;

        //Updating the peak:
        if (bar_height > peak_height) {
        	peak_height = bar_height; //Push it up right now
        	gravity_counter = 0; //Set falling timer to 0
        } else {
        	gravity_counter++;
        	if (gravity_counter > 500) {
        		if (peak_height > 0) peak_height --;
        		gravity_counter = 0;
        	}
        }

        u32 packed_data = (peak_height << 16) | bar_height;
        //Send calculated height to HDMI Hardware
        XGpio_DiscreteWrite(&Gpio_Gfx, 1, packed_data);



        //Tiny delay to prevent screen flicker
        usleep(5000); // Update 200 times per second
    }

    cleanup_platform();
    return 0;
}
