import { BadRequestException } from '@nestjs/common';
import type * as SharpTypes from 'sharp';
// eslint-disable-next-line @typescript-eslint/no-var-requires
const sharp: (...args: any[]) => SharpTypes.Sharp = require('sharp');

export type ImageUploadKind =
  | 'vehicle_listing'
  | 'vehicle_detail'
  | 'vehicle_colour'
  | 'accessory';

export interface ProcessedImageResult {
  dataUri: string;
  mimeType: string;
  width: number;
  height: number;
  originalWidth: number;
  originalHeight: number;
  sizeKb: number;
  qualityScore: 'excellent' | 'acceptable';
  warnings: string[];
}

interface ImageSpec {
  minShortestSide: number;
  minTotalPixels: number;
  recommendedShortestSide: number;
  targetLandscape: [number, number];
  targetPortrait: [number, number];
  minRatio: number;
  maxRatio: number;
  maxFileBytes: number;
  label: string;
}

const IMAGE_SPECS: Record<ImageUploadKind, ImageSpec> = {
  vehicle_listing: {
    minShortestSide: 420,
    minTotalPixels: 240000, // Allows crisp 500x736 portrait cards or 600x400+ landscape
    recommendedShortestSide: 600,
    targetLandscape: [900, 675],
    targetPortrait: [600, 800],
    minRatio: 0.5,
    maxRatio: 2.5,
    maxFileBytes: 10 * 1024 * 1024,
    label: 'Vehicle Listing Card',
  },
  vehicle_detail: {
    minShortestSide: 420,
    minTotalPixels: 250000,
    recommendedShortestSide: 650,
    targetLandscape: [1000, 800],
    targetPortrait: [750, 950],
    minRatio: 0.55,
    maxRatio: 2.5,
    maxFileBytes: 10 * 1024 * 1024,
    label: 'Vehicle Detail Studio View',
  },
  vehicle_colour: {
    minShortestSide: 420,
    minTotalPixels: 250000,
    recommendedShortestSide: 650,
    targetLandscape: [1000, 800],
    targetPortrait: [750, 950],
    minRatio: 0.55,
    maxRatio: 2.5,
    maxFileBytes: 10 * 1024 * 1024,
    label: 'Vehicle Colour Image',
  },
  accessory: {
    minShortestSide: 200,
    minTotalPixels: 40000,
    recommendedShortestSide: 400,
    targetLandscape: [400, 400],
    targetPortrait: [400, 400],
    minRatio: 0.45,
    maxRatio: 2.2,
    maxFileBytes: 5 * 1024 * 1024,
    label: 'Accessory Thumbnail',
  },
};

/**
 * Validates resolution, format, aspect ratio, and normalizes uploaded images
 * to optimized WebP with clean framing so low-quality or distorted images
 * never degrade the customer configurator UI.
 */
export async function processUploadedImage(
  file: Express.Multer.File | undefined,
  kind: ImageUploadKind,
): Promise<ProcessedImageResult> {
  if (!file || !file.buffer || file.buffer.length === 0) {
    throw new BadRequestException('Please upload a valid PNG, JPG, or WebP image file.');
  }

  const spec = IMAGE_SPECS[kind];
  if (file.buffer.length > spec.maxFileBytes) {
    throw new BadRequestException(
      `Image file is too large (${(file.buffer.length / (1024 * 1024)).toFixed(1)} MB). Maximum allowed is ${Math.round(spec.maxFileBytes / (1024 * 1024))} MB.`,
    );
  }

  let metadata: SharpTypes.Metadata;
  try {
    metadata = await sharp(file.buffer).rotate().metadata();
  } catch {
    throw new BadRequestException(
      'Uploaded file is not a supported or valid image (PNG, JPG, WebP expected).',
    );
  }

  const supportedFormats = ['jpeg', 'jpg', 'png', 'webp', 'tiff', 'avif'];
  if (!metadata.format || !supportedFormats.includes(metadata.format.toLowerCase())) {
    throw new BadRequestException(
      `Unsupported image format "${metadata.format || 'unknown'}". Please upload a PNG, JPG, or WebP image.`,
    );
  }

  // Account for EXIF orientation swap (5,6,7,8 swap width/height)
  const needsSwap = metadata.orientation && metadata.orientation >= 5;
  const origW = needsSwap ? (metadata.height || 0) : (metadata.width || 0);
  const origH = needsSwap ? (metadata.width || 0) : (metadata.height || 0);
  const shortest = Math.min(origW, origH);
  const totalPixels = origW * origH;

  if (shortest < spec.minShortestSide || totalPixels < spec.minTotalPixels) {
    throw new BadRequestException(
      `Image resolution too low for ${spec.label} (${origW}×${origH}px). Upload a sharp photo (minimum ${spec.minShortestSide}px short side).`,
    );
  }

  const ratio = origW / Math.max(1, origH);
  if (ratio < spec.minRatio || ratio > spec.maxRatio) {
    throw new BadRequestException(
      `Image aspect ratio (${ratio.toFixed(2)}:1) is too narrow or stretched for ${spec.label}. Please upload a balanced product photo.`,
    );
  }

  const warnings: string[] = [];
  let qualityScore: 'excellent' | 'acceptable' = 'excellent';
  if (shortest < spec.recommendedShortestSide) {
    qualityScore = 'acceptable';
    warnings.push(
      `Uploaded ${origW}×${origH}px. For best sharpness on large tablets, ${spec.recommendedShortestSide}px+ short side is recommended.`,
    );
  }

  const [targetW, targetH] = origH > origW ? spec.targetPortrait : spec.targetLandscape;
  const hasAlpha = Boolean(metadata.hasAlpha);
  const bg = hasAlpha
    ? { r: 255, g: 255, b: 255, alpha: 0 }
    : { r: 255, g: 255, b: 255, alpha: 1 };

  const webpBuffer = await sharp(file.buffer)
    .rotate()
    .resize(targetW, targetH, {
      fit: 'contain',
      background: bg,
      withoutEnlargement: false,
    })
    .webp({ quality: 84, alphaQuality: 90 })
    .toBuffer();

  const outMeta = await sharp(webpBuffer).metadata();
  const dataUri = `data:image/webp;base64,${webpBuffer.toString('base64')}`;

  return {
    dataUri,
    mimeType: 'image/webp',
    width: outMeta.width || targetW,
    height: outMeta.height || targetH,
    originalWidth: origW,
    originalHeight: origH,
    sizeKb: Math.round(webpBuffer.length / 1024),
    qualityScore,
    warnings,
  };
}
