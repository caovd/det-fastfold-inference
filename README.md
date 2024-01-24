# det-fastfold-inference
Run FastFold inference uing HPE Machine Learning Development Environment (aka MLDE)

Advantages of running training/inference processes on MLDE:

- **Simplified environment setting**: Set up a notebook config file notebook.yaml that provides a readily built docker image by Determined AI (aka MLDE) and available on DockerHub. These docker images are frequently released and users just need to pick and choose the right image which, in this example, requires CUDA 11.3 and Pytorch >= 1.12.

- **Containerised environment**: Process environment is isolated from the host OS, so users do have constraint with upgrading/downgrading packages

- **Automated GPU resource procurement** by only defining slots number in a config file

- **Automated SSH** In case you launch a shell, the SSH access to the launched shell environment without the need to manually setup and manage credentials when connecting to a remote cluster is automatically setup by MLDE

# References: 
1. [FastFold github repo](https://github.com/hpcaitech/FastFold/tree/main)
2. [How to start a Jupyter Notebook in MLDE](https://hpe-mlde.determined.ai/latest/tools/notebooks.html#jupyter-notebooks)

# Method
## Step 1: Launch a MDLE notebook
### 1.1 Start a MLDE notebook. 

```yaml
description: fastfold-inference
environment:
  image: caovd/fastfold-1.0:v2
  environment_variables:
    - NCCL_DEBUG=INFO
    - PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000
    # You need to set PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000 to inference such an extreme long sequence.
    # You may need to modify this to match your network configuration.
    - NCCL_SOCKET_IFNAME=ens,eth,ib
resources:
  slots: 8
  resource_pool: A100
```

Note: Users can define an environment variable inside notebook.yaml, ex., "PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000" which is used to inference extremely long sequences.

```bash
det -m <mlde-master> notebook start --config-file notebook.yaml -c .
```

## Step 2: Setup environment (Optional)

You don't need to setup environment manually, as it's handled by MLDE automatically. A custom docker image, ```caovd/fastfold-1.0```,  was created and referred to in the notebok.yaml. Additionally, you can customize startup-hook.sh to add custom packages and dependencies, to add flexibility and adaptability to changing requirements. 

## Step 3: Run inference
### 3.1 Edit the inference.sh file

```bash
# add '--gpus [N]' to use N gpus for inference
# add '--enable_workflow' to use parallel workflow for data processing
# add '--use_precomputed_alignments [path_to_alignments]' to use precomputed msa
# add '--chunk_size [N]' to use chunk to reduce peak memory
# add '--inplace' to use inplace to save memory

python inference.py /PATH/TO/fastfold/data/fasta_dir/5005.fasta /PATH/TO/openfold/data/pdb_mmcif/data/files \
    --output_dir /PATH/TO/fastfold/outputs \
    --gpus 8 \
    --uniref90_database_path /PATH/TO/openfold/data/uniref90/uniref90.fasta \
    --mgnify_database_path /PATH/TO/openfold/data/mgnify/mgy_clusters_2018_12.fa \
    --pdb70_database_path /PATH/TO/openfold/data/pdb70/pdb70 \
    --uniref30_database_path /PATH/TO/openfold/data/uniref30/UniRef30_2021_03 \
    --bfd_database_path /PATH/TO/openfold/data/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
    --jackhmmer_binary_path `which jackhmmer` \
    --hhblits_binary_path `which hhblits` \
    --hhsearch_binary_path `which hhsearch` \
    --kalign_binary_path `which kalign` \
    --enable_workflow \
    --param_path /PATH/TO/fastfold/data/params/params_model_1_ptm.npz \
    --use_precomputed_alignments /PATH/TO/fastfold/outputs/alignments \
    --chunk_size 32 \
    --inplace
```

### 3.2 Run inference
```shell
bash inference.sh arg1 arg2 arg3
```
arg1: # of residues in fasta file
arg2: # of GPUs
arg3: chunk size

![](/assets/gpu_util_5005.png)

## Notes: 
### Pytorch CUDA memory allocation

Set `PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:15000` to inference long sequence, ex., 8K or 10K residues.

