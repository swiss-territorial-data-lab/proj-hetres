# -*- coding: utf-8 -*-
"""
Created on Tue Jan  3 12:11:39 2023

@author: cmarmy
"""

import torch
from torch import nn

dtype = torch.float
device = torch.device("cpu")

import torchvision.models as models

resnet18 = models.resnet18(pretrained=True)