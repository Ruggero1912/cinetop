# cinetop 🚀

A lightweight terminal dashboard and SSH toolkit for **CINECA HPC clusters** (**Leonardo**, **Galileo100**, etc.), featuring real-time multi-node SLURM GPU monitoring, SSH connection multiplexing, and automated 2FA certificate renewal (`step-cli`).

---

## ✨ Features

* **`cinetop` Live Dashboard:** An `nvitop`-style real-time terminal monitor for SLURM jobs running across multiple compute nodes:
  * **Parallel GPU Polling:** Queries `utilization.gpu`, `VRAM used/total`, and `temperature` across all your active nodes simultaneously via `srun --overlap` (100% safe and read-only).
  * **Grant Hours Tracking:** Displays consumed vs. total GPU/CPU hours for your active ISCRA/CINECA project (`saldo -b`, cached every 10 minutes for zero latency).
  * **Live Partition Load Bar:** Shows real-time node saturation (`Allocated / Available / Idle` nodes) on your target SLURM partition (e.g., `boost_usr_prod`).
  * **Smart Sorting & History:** Sorts running jobs by **Elapsed Time (descending)**, lists queued (`PENDING`) jobs with their SLURM reason, and shows your **last 5 finished jobs** (`COMPLETED`, `FAILED`, `TIMEOUT`, `CANCELLED`) ordered from most recent to oldest.
* **Zero-Friction SSH & Auto-Renewal:**
  * Configures SSH Multiplexing (`ControlMaster` / `ControlPersist`) so subsequent `ssh`, `rsync`, and `sbatch` calls execute in **0.03s** instead of 2.5s.
  * Automatically detects when your 12-hour CINECA `step-cli` certificate has expired and triggers the Keycloak 2FA renewal flow before opening `cinetop`.

---

## 🖥️ Preview (`cinetop`)

```text
CINECA HPC GPU Monitor | User: user01 | Running: 4 | Pending: 0 | Grant IscrC_PROJ: 4210 / 50000 h (8.4%)
Partition Load (boost_usr_prod): [############---] 82% (2696/3288 active GPU nodes, 592 idle)
=====================================================================================================================
JOBID      | EXPERIMENT NAME                            | NODE     | ELAPSED    | GPU %  | VRAM (USED/TOT)    | TEMP
---------------------------------------------------------------------------------------------------------------------
58104210   | vit-large-imagenet-bs256-lr1e4             | lrdn0412 | 04:12:18   |   98%  | 48210 / 65536 MiB  |  62°C
58104215   | resnet50-ablation-aug-mixup                | lrdn1108 | 02:45:09   |   94%  | 22400 / 65536 MiB  |  58°C
58104390   | llama3-8b-lora-finetune-r16                | lrdn2305 | 01:18:44   |   99%  | 59120 / 65536 MiB  |  65°C
58104812   | clip-zero-shot-eval-coco                   | lrdn0194 | 00:14:22   |   45%  | 11200 / 65536 MiB  |  49°C
---------------------------------------------------------------------------------------------------------------------
Last 5 Finished Jobs (past 3 days):
  58103990   | bert-base-ner-seed42                       | COMPLETED  | Elapsed: 01:42:10   | End: 2026-03-15T16:20:11
  58103104   | llama3-8b-lora-finetune-r32                | TIMEOUT    | Elapsed: 1-00:00:02 | End: 2026-03-15T11:05:00
  58099812   | vit-base-patch16-warmup5k                  | COMPLETED  | Elapsed: 05:18:33   | End: 2026-03-14T22:41:19
  58098401   | ddpm-cifar10-test-run                      | FAILED     | Elapsed: 00:03:12   | End: 2026-03-14T14:10:05
  58095120   | resnet50-baseline-sgd                      | COMPLETED  | Elapsed: 03:50:48   | End: 2026-03-13T19:30:42
```

---

## 🛠️ Prerequisites (One-Time Setup on Your Local Machine)

### 1. Install `step-cli` (No `sudo` required)
If `step` is not installed on your local machine (Linux, macOS, WSL2, or remote dev workstation), install the standalone binary in `~/.local/bin`:

```bash
mkdir -p ~/.local/bin
curl -sL https://dl.smallstep.com/cli/docs-cli-install/latest/step_linux_amd64.tar.gz | tar -xz -C /tmp
mv /tmp/step_*/bin/step ~/.local/bin/step
chmod +x ~/.local/bin/step
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### 2. Bootstrap CINECA Certificate Authority
Link `step-cli` to CINECA's official SSH proxy CA:

```bash
step ca bootstrap --ca-url=https://sshproxy.hpc.cineca.it --fingerprint 2ae1543202304d3f434bdc1a2c92eff2cd2b02110206ef06317e70c1c1735ecd
```

> **Note on CA Fingerprint:** If CINECA rotates its Root CA certificate in the future, you can find the updated `--fingerprint` value in the [official CINECA 2FA & step-cli documentation](https://docs.hpc.cineca.it/general/access.html), or inspect your currently configured fingerprint inside `~/.step/config/defaults.json`.

---

## 🚀 Quick Start & Installation

1. **Clone the repository on your machine:**
   ```bash
   git clone https://github.com/Ruggero1912/cinetop.git
   cd cinetop
   ```

2. **Create your local `config.env` (git-ignored):**
   ```bash
   cp config.env.example config.env
   nano config.env
   ```
   Fill in your details:
   * `CINECA_USER`: Your UNIX username on CINECA (check on [userdb.hpc.cineca.it](https://userdb.hpc.cineca.it)).
   * `CINECA_ACCOUNT`: Your SLURM project grant name (check via `saldo -b`).
   * `KEYCLOAK_EMAIL`: Your institutional email used for 2FA login.
   * *(Optional)* Customize `CINECA_HOSTNAME`, `CINECA_PARTITION`, and `CINECA_WORK_BASE` if using a cluster other than Leonardo (defaults to Leonardo `boost_usr_prod`).

3. **Run the installer:**
   ```bash
   ./install.sh
   ```
   `install.sh` will automatically:
   * Save your configuration in `~/.config/cinetop/config.env`.
   * Configure `~/.ssh/config` with `ControlMaster` and `ControlPersist`.
   * Prompt for 2FA login via `step-cli` if your certificate is missing or expired.
   * Deploy the `cinetop` scripts to `$CINECA_WORK_BASE/$CINECA_ACCOUNT/$CINECA_USER/bin` on the cluster and `~/.local/bin/cinetop` locally.

---

---

## ⚡ Performance & Best Practices (`srun --overlap`)

`cinetop` queries active compute nodes in parallel using SLURM's `--overlap` flag combined with `nvidia-smi`. 

* **Why it's lightweight:** It communicates directly with the local `slurmd` daemon on each allocated node rather than hammering the central cluster scheduler (`slurmctld`).
* **Recommended interval:** The default 4-second refresh (`cinetop 4`) imposes zero noticeable overhead on compute nodes or GPU training loops. Avoid setting aggressive refresh intervals (e.g., `cinetop 1`) if you are running a high volume of concurrent jobs across many nodes.

## 📊 Usage

* **From your local terminal (or remote dev workstation):**
  ```bash
  cinetop        # Refreshes every 4 seconds (default)
  cinetop 2      # Refreshes every 2 seconds
  ```
  *(If your 12-hour SSH certificate has expired, `cinetop` will automatically prompt you to authenticate via `step-cli` and then launch the monitor).*

* **Directly on a CINECA Login Node:**
  ```bash
  cinetop
  ```

* **Optional Windows `.bat` Launcher:**
  See `windows/cinetop.bat.example` if you want a one-click desktop shortcut to launch `cinetop` over SSH from Windows.

---

## 📁 Repository Structure

```text
cinetop/
├── config.env.example        # Configuration template (safe to commit)
├── install.sh                # Automated local + remote installer
├── local/
│   └── cinetop               # Local wrapper with step-cli auto-renewal
├── remote/
│   ├── cinetop               # Remote watch wrapper on CINECA
│   └── _cinetop_worker       # Parallel SLURM + nvidia-smi dashboard engine
└── windows/
    └── cinetop.bat.example   # Optional Windows one-click launcher template
```
