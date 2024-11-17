import { device } from "../renderer";
import * as fs from 'fs';
import { vec3 } from 'wgpu-matrix';

export type JerlovWaterType = 
    | 'b_IA'
    | 'c_IA'
    | 'c_IB'
    | 'd_II'
    | 'e_III'
    | 'f_1C'
    | 'g_3C'
    | 'h_5C'
    | 'i_7C';

type WaterProps = {
    'sigma_s': number,
    'sigma_t': number,
    'kd': number,
};

type JerlovWaterProps = {
    [key in JerlovWaterType]: WaterProps[];
};

type WaterPropsData = {
    jerlovWaterProps: JerlovWaterProps,
    wavelengths: number[]
};

export const { jerlovWaterProps, wavelengths} : WaterPropsData = JSON.parse(fs.readFileSync("waterprops/data.json", 'utf-8'));

export type SensitivityType = | 'cie';

export class ScatteringUniforms {
    private readonly numWavelengths: number;

    private readonly waterPropsBuffer: ArrayBuffer;
    private readonly waterPropsFloatView: Float32Array;
    private readonly waterPropsGPUBuffer: GPUBuffer;

    private readonly sensitivitiesBuffer: ArrayBuffer;
    private readonly sensitivitiesFloatView: Float32Array;
    private readonly sensitivitiesGPUBuffer: GPUBuffer;

    constructor(numWavelengths: number) {
        this.numWavelengths = numWavelengths;
        
        this.waterPropsBuffer = new ArrayBuffer(numWavelengths * 4 * 4);
        this.waterPropsFloatView = new Float32Array(this.waterPropsBuffer);
        this.waterPropsGPUBuffer = device.createBuffer({
            label: "water properties",
            size: this.waterPropsBuffer.byteLength,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        this.sensitivitiesBuffer = new ArrayBuffer(numWavelengths * 4 * 4);
        this.sensitivitiesFloatView = new Float32Array(this.waterPropsBuffer);
        this.sensitivitiesGPUBuffer = device.createBuffer({
            label: "sensitivities",
            size: this.sensitivitiesBuffer.byteLength,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });
    }

    setWaterProps(jerlovWaterType: JerlovWaterType) {
        const waterProperties = jerlovWaterProps[jerlovWaterType];
        for (let i = 0; i < this.numWavelengths; i++) {
            const offset = i * 4;
            this.waterPropsFloatView[offset] = waterProperties[i].sigma_s;
            this.waterPropsFloatView[offset + 1] = waterProperties[i].sigma_t;
            this.waterPropsFloatView[offset + 2] = waterProperties[i].kd;
            this.waterPropsFloatView[offset + 3] = 0;
        }

        device.queue.writeBuffer(this.waterPropsGPUBuffer, 0, this.waterPropsBuffer);
    }

    setSensitivities(sensititivityType: SensitivityType) {
        let sensitivities = new Float32Array(this.numWavelengths); // TODO: Create file for cie sensitivity
        this.sensitivitiesFloatView.set(sensitivities);
        device.queue.writeBuffer(this.sensitivitiesGPUBuffer, 0, this.sensitivitiesBuffer);
    }
}