import { device } from "../renderer";
import * as fs from 'fs';
import { vec3 } from 'wgpu-matrix';

export const JerlovWaterTypes = ['b_IA', 'c_IA', 'c_IB', 'd_II', 'e_III', 'f_1C', 'g_3C', 'h_5C', 'i_7C'] as const;
export type JerlovWaterType = typeof JerlovWaterTypes[number];

export type WaterProps = {
    'sigma_s': number,
    'sigma_t': number,
    'kd': number,
};

export type JerlovToWaterProps = {
    [key in JerlovWaterType]: WaterProps[];
};

export const SensitivityTypes = ['cie']
export type SensitivityType = typeof SensitivityTypes[number];
export type SensitivityTypeToSensitivities = {
    [key in SensitivityType]: [number, number, number][];
};

export type SpectralData = {
    wavelengths: number[],
    wavelengthWeights: number[],
    jerlovWaterProps: JerlovToWaterProps,
    sensitivities: SensitivityTypeToSensitivities,
};

export async function loadSpectralData(filename: string): Promise<SpectralData> {
    const response = await fetch(filename);
    const data = await response.json();
    return data as SpectralData;
}

export class SpectralUniforms {
    private readonly spectralData: SpectralData;
    private readonly numWavelengths: number;

    private readonly wavelengthBuffer: ArrayBuffer;
    private readonly wavelengthFloatView: Float32Array;
    private readonly wavelengthGPUBuffer: GPUBuffer;

    private readonly waterPropsBuffer: ArrayBuffer;
    private readonly waterPropsFloatView: Float32Array;
    private readonly waterPropsGPUBuffer: GPUBuffer;

    private readonly sensitivitiesBuffer: ArrayBuffer;
    private readonly sensitivitiesFloatView: Float32Array;
    private readonly sensitivitiesGPUBuffer: GPUBuffer;

    public spectralBindGroupLayout: GPUBindGroupLayout;
    public spectralBindGroup: GPUBindGroup;

    constructor(spectralData: SpectralData) {
        this.spectralData = spectralData;
        this.numWavelengths = spectralData.wavelengths.length;

        this.wavelengthBuffer = new ArrayBuffer(this.numWavelengths * 4 * 2);
        this.wavelengthFloatView = new Float32Array(this.wavelengthBuffer);
        this.wavelengthGPUBuffer = device.createBuffer({
            label: "wavelengths",
            size: this.wavelengthBuffer.byteLength,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        // For now the wavelength buffer never changes, so we just set it once at the beginning
        for (let i = 0; i < this.numWavelengths; i++) {
            this.wavelengthFloatView[i * 2] = spectralData.wavelengths[i];
            this.wavelengthFloatView[i * 2 + 1] = spectralData.wavelengthWeights[i];
        }
        device.queue.writeBuffer(this.wavelengthGPUBuffer, 0, this.wavelengthBuffer);
        
        this.waterPropsBuffer = new ArrayBuffer(this.numWavelengths * 4 * 4);
        this.waterPropsFloatView = new Float32Array(this.waterPropsBuffer);
        this.waterPropsGPUBuffer = device.createBuffer({
            label: "water properties",
            size: this.waterPropsBuffer.byteLength,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        this.sensitivitiesBuffer = new ArrayBuffer(this.numWavelengths * 4 * 4);
        this.sensitivitiesFloatView = new Float32Array(this.waterPropsBuffer);
        this.sensitivitiesGPUBuffer = device.createBuffer({
            label: "sensitivities",
            size: this.sensitivitiesBuffer.byteLength,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        this.spectralBindGroupLayout = device.createBindGroupLayout({
            label: "scattering bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                {
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                {
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                }
            ]
        });

        this.spectralBindGroup = device.createBindGroup({
            layout: this.spectralBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.wavelengthGPUBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.waterPropsGPUBuffer }
                },
                {
                    binding: 2,
                    resource: { buffer: this.sensitivitiesGPUBuffer }
                }
            ]
        });

        this.setWaterProps('b_IA');
        this.setSensitivities('cie');
    }

    setWaterProps(jerlovWaterType: JerlovWaterType) {
        const waterProperties = this.spectralData.jerlovWaterProps[jerlovWaterType];
        for (let i = 0; i < this.numWavelengths; i++) {
            const offset = i * 4;
            this.waterPropsFloatView[offset] = waterProperties[i].sigma_s;
            this.waterPropsFloatView[offset + 1] = waterProperties[i].sigma_t;
            this.waterPropsFloatView[offset + 2] = waterProperties[i].kd;
            this.waterPropsFloatView[offset + 3] = 0;
        }

        device.queue.writeBuffer(this.waterPropsGPUBuffer, 0, this.waterPropsBuffer);
    }

    setSensitivities(sensitivityType: SensitivityType) {
        let sensitivities = this.spectralData.sensitivities[sensitivityType].flat();
        this.sensitivitiesFloatView.set(sensitivities);
        device.queue.writeBuffer(this.sensitivitiesGPUBuffer, 0, this.sensitivitiesBuffer);
    }
}