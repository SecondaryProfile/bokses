#!/usr/bin/env python3
"""
Generate text embeddings for OpenCLIP ViT-L/14 zero-shot classification.

Requirements:
    pip install open_clip_torch torch

Usage:
    python generate_clip_embeddings.py [path/to/imagenet_labels.txt]

Output format (little-endian):
    int32  numClasses
    int32  embedDim
    float32[numClasses * embedDim]  L2-normalised embeddings
"""

import sys
import os
import struct
import torch
import open_clip

LABELS_DEFAULT = os.path.join(os.path.dirname(__file__), '..', 'imagenet_labels.txt')
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'bokses_cv_xl_embeddings.bin')
MODEL_NAME = 'laion/CLIP-ViT-L-14-laion2B-s32B-b82K'
TEMPLATE = 'a photo of a {label}'


def main():
    labels_path = sys.argv[1] if len(sys.argv) > 1 else LABELS_DEFAULT
    with open(labels_path, 'r', encoding='utf-8') as f:
        all_labels = [line.strip() for line in f.readlines()]

    # Skip background at index 0
    labels = [l for i, l in enumerate(all_labels) if i != 0 and l and l.lower() != 'background']
    num_classes = len(labels)

    print(f'Loading model {MODEL_NAME} ...')
    model, _, _ = open_clip.create_model_and_transforms(
        'ViT-L-14',
        pretrained='laion2b_s32b_b82k',
    )
    model.eval()
    tokenizer = open_clip.get_tokenizer('ViT-L-14')

    print(f'Encoding {num_classes} labels ...')
    texts = [TEMPLATE.format(label=l) for l in labels]
    tokens = tokenizer(texts)

    batch_size = 128
    all_embeddings = []
    with torch.no_grad():
        for i in range(0, len(tokens), batch_size):
            batch = tokens[i:i + batch_size]
            emb = model.encode_text(batch)
            emb = emb / (emb.norm(dim=-1, keepdim=True) + 1e-8)
            all_embeddings.append(emb.cpu().float())
            if (i // batch_size) % 10 == 0:
                print(f'  {i}/{len(tokens)}')

    embeddings = torch.cat(all_embeddings, dim=0)
    embed_dim = embeddings.shape[1]

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, 'wb') as f:
        f.write(struct.pack('<ii', num_classes, embed_dim))
        f.write(embeddings.numpy().tobytes())

    print(f'Written: {OUTPUT_PATH}')
    print(f'  numClasses={num_classes}, embedDim={embed_dim}')
    print()
    print('Upload this file and set embeddingsUrl in lib/models/cv_model_def.dart')


if __name__ == '__main__':
    main()
