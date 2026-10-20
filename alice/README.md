# alice

The scripts in `scripts/` were written by Claude and tested extensively by a
human.

## Giving alice access to Frigate

The compose file expects `ALICE_FRIGATE_DIR` (default `./data/frigate`) to
contain Frigate's `config/` and `data/{clips,exports}`, mounted read-only at
`/app/frigate`, `/app/clips` and `/app/exports`. If your Frigate layout
differs, change the bind sources.

- Mount Frigate's whole `config/` directory, not just `frigate.db`. The
  database won't open on its own.
- If the Frigate mount is missing, alice won't start.
- For Frigate on another host, `scripts/mount-frigate.sh host:/path/to/frigate`
  mounts it read-only over sshfs. It needs `user_allow_other` in
  `/etc/fuse.conf`. The mount doesn't survive a reboot. If it drops while
  alice is running, rerun the script and recreate the container.
- `scripts/teardown.sh` stops alice and unmounts.

## Terms

- **Viewer / Trainer / Settings:** the pages, at the top of the left
  sidebar.
- **Viewer > Dataset / Live / Video mode:** the Viewer's modes, the second
  group in the left sidebar, below Settings. They only appear while the
  Viewer is open, so click **Viewer** first.
- **Settings > X:** click **Settings** in the left sidebar, then button X in
  the Settings page's top toolbar (Paths, AI, Training, Dedup, ...).
  Changes apply on **✓ Save**, in the same toolbar.
- **Dataset picker:** the dropdown under the **Dataset** heading at the top
  of the Trainer's right-hand panel, above **Pipeline Steps**. Every Trainer
  step acts on it.
- **Pipeline Steps > X:** step X in the Trainer's right-hand panel. Each
  step's row is also the button that opens its page, so click the step's
  name. The checkbox in the row only selects it for "Run Selected
  Pipeline", which you won't use.
- **Config / Logs:** buttons at the right of the Trainer's top toolbar,
  next to **Device**. **Logs** has the real results of each step, and
  **Config** goes back to the open step's page.
- **Viewer dropdown:** the first control at the left of the Viewer's top
  toolbar, before the **All / Train / Val / Empty** buttons. It only shows
  in Dataset mode and reads the open dataset's name, e.g. `default`.
  **+ Create New Dataset** is its last entry. It's separate from the Dataset
  picker.
- **Edit / AI tab:** tabs along the top of the Viewer's right-hand panel
  (in Dataset mode: **Edit**, **AI**, **Dupes**, **Stats**). If the panel is
  collapsed to a strip labelled **Panel**, click it to open it.

alice reopens whatever page and mode you last used, so every procedure below
starts by clicking a page in the left sidebar, whatever is open.

## First-run settings

Click **Settings** in the left sidebar. Each section below is a button in the
Settings page's top toolbar.

### Settings > Paths

| Field                   | Value                     |
| ----------------------- | ------------------------- |
| Frigate Clips (Live)    | `/app/clips`              |
| Frigate Exports (Video) | `/app/exports`            |
| Frigate DB              | `/app/frigate/frigate.db` |

**Server > Port** has no effect. Set `ALICE_PORT` in `.env` instead.

### Settings > AI

Under **Download Models**, download `yolo11l` and `yolo11s` first. Then fill
in **AI Defaults**:

| Field              | Value                                            | Why                                                                                                          |
| ------------------ | ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------ |
| Default Model      | `yolo11l.pt`                                     | Used for previews in the Viewer. Accuracy matters more than speed here.                                      |
| Teacher Model      | `yolo11l.pt`                                     | Writes the labels in Annotate. Same reasoning.                                                               |
| Student Model      | `yolo11s.pt`                                     | The base for the model Frigate runs. Small enough to run at the same cost as Frigate's recommended YOLOv9-s. |
| Default Confidence | `0.7`                                            | Used for labels written without review, so they should be precise.                                           |
| Classes            | Tick the objects you want, e.g. person, cat, dog | Only these get labelled.                                                                                     |

Only COCO classes are available.

**vs Frigate+:** Frigate+ labels such as `face`, `package`, `license_plate`
and delivery logos don't exist here.

### Settings > Training

| Field         | Value     | Why                                                        |
| ------------- | --------- | ---------------------------------------------------------- |
| Epochs        | `50`      | The default of 10 is too few.                              |
| Batch Size    | `8`       | Fine on CPU.                                               |
| Learning Rate | (ignored) | alice doesn't apply it.                                    |
| LR Final      | `0.01`    | Default.                                                   |
| Image Size    | `320`     | Must match the ONNX export and Frigate's `width`/`height`. |
| Freeze Layers | `10`      | Default. Right for a few thousand images.                  |
| Augmentation  | on        | Without it, the model overfits to your fixed camera views. |

### Settings > Dedup

| Field        | Value                  | Why                                                        |
| ------------ | ---------------------- | ---------------------------------------------------------- |
| Box Dedup    | off                    | Deletes all but one empty frame per camera.                |
| Visual pHash | on, Similarity **100** | See below.                                                 |
| NMS Cleanup  | on, Similarity `85`    | Removes overlapping duplicate boxes. Never deletes images. |

On fixed cameras most frames look nearly identical to pHash, so anything
below 100 deletes real variety. Measured on 592 snapshots from two cameras:

| pHash similarity     | Images kept |
| -------------------- | ----------- |
| 85 (alice's default) | 80          |
| 95                   | 404         |
| 100                  | 539         |

Press **Save**.

## How the workflow is shaped

Annotate relabels every image in the selected dataset, and alice doesn't
track which images you've reviewed. The workflow therefore uses two datasets:

- `default`: reviewed images, and what you train on.
- `staging`: new images get exported, deduped, annotated and
  reviewed here, then merged into `default`.

Annotate is never run on `default`.

**vs Frigate+:** there's no verified/unverified state. The
`staging`/`default` split stands in for it.

## Warnings

These either destroy work or quietly give you a bad model. Each one is
repeated where it applies.

- **Never run "Annotate" on `default`.** It overwrites every label in the
  dataset, wiping your review. To fix labels in `default`, edit them by hand
  in the Viewer. The only exception is adding a class (see section
  ["Updating the model"](#updating-the-model) of this README), with only the
  new class ticked and **Merge with existing
  annotations** ticked.
- **Leave "Merge with existing annotations" unticked on a normal "Annotate".**
  Ticked, it brings back boxes you deleted.
- **Never run the single-image "Analyse" on an image you've reviewed.** That's
  the **◎ Analyse (A)** button in the Viewer's **AI** tab, the **A** key, or
  **🤖 AI Analyse** in the image's right-click menu. It saves its own
  detections to the open image and brings back boxes you deleted. Don't
  worry if you do it by accident, though: it only affects that one image,
  not the whole dataset. Just delete the extra boxes it added.
- **Never use "Run Selected Pipeline".** It ignores your settings for any step
  whose page isn't open, including dedup at 85%, which deletes most of your
  images. Open each step from **Pipeline Steps** (click its name, not the
  checkbox) and use the button on that page.
- **Keep the pHash "Similarity" at 100.** Anything lower deletes most of your
  images on fixed cameras.
- **Run `scripts/datasets.sh merge` before running "Annotate" again.**
  Otherwise that Annotate wipes the review you haven't merged yet.
- **Check the Dataset picker before every Trainer step.** It's the dropdown
  under **Dataset** at the top of the Trainer's right-hand panel. Annotate on
  the wrong dataset can't be undone.
- **Never press "Move" in "Live" mode.** It tries to delete the snapshot from
  Frigate. This stack mounts Frigate read-only, so it just fails here, but
  it would really delete the snapshot if alice could write to Frigate's
  files. Use **Copy (M)**.
- **Always train from `yolo11s.pt`,** never from the previous
  `yolo11s-finetuned.pt`. That would carry its mistakes forward and keep
  classes you've dropped.

## From nothing to a model

### 1. Collect

1. First time only: click **Viewer** in the left sidebar, then **Dataset**,
   which appears below **Settings**. Open the dropdown at the far left of
   the Viewer's top toolbar, the one showing the open dataset's name (e.g.
   `default`). Pick **+ Create New Dataset**, its last entry, and name it
   `staging`.
2. Click **Trainer** in the left sidebar. In the dropdown under **Dataset**
   at the top of the right-hand panel, pick `staging`.
3. **Pipeline Steps > Export**. Set **Max Images** to `1000`, then press
   **Export Dataset** without leaving the page, because "Max Images" resets
   to 100.
4. Skip this step on your very first export, while `default` is still
   empty. On every export after that, Export also brings back events you've
   already merged into `default`. Remove them from `staging` so you don't
   review them twice:

   ```sh
   scripts/datasets.sh prune
   ```

   Add `-n` first to see what it would delete.
5. **Pipeline Steps > Dedup**. Check pHash similarity reads 100, press
   **Dry Run**, then click **Logs** at the right of the Trainer's top toolbar
   and check the counts there (the summary popup can say 0). Click
   **Config**, two buttons to the left of **Logs**. It shows the Dry Run's
   report instead of the Dedup settings, so press **Dismiss** at the bottom
   of the report. Check pHash similarity still reads 100, then press **Run
   Dedup**.

> **Warning:** keep pHash similarity at 100, and press **Run Dedup** on this
> page, never **Run Selected Pipeline**. Either mistake deletes most of your
> images.

Re-exporting into `staging` is safe, and Dedup removes the occasional
duplicate.

**Lookalike snapshots:** Frigate makes one event per tracked object, so two
people and a dog walking past give three events, each with its own snapshot
taken a few seconds apart. They have different event IDs, so `prune` keeps
them, and they aren't identical, so Dedup at 100 keeps them too. Leave them
in. Nearly all of them differ in pose, framing or who's in view, and that's
useful variety. Of 10 such pairs checked, none was a real duplicate. If you
do find two that genuinely show the same moment, delete one of them:

- One in `staging`, one in `default`: delete the `staging` one. The one in
  `default` is the one you've already reviewed, so leave it alone.
- Both in `staging`: delete either.

- Don't try to catch them by time. An event's start time, the number in its
  ID, can be close to another's while their snapshots are up to a minute
  apart.
- Don't try to catch them with a looser pHash either. A threshold that
  catches most of them also matches hundreds of unrelated frames from the
  same camera.

You can only export what Frigate still has, so collect at least as often as
your shortest `snapshots.retain`.

**vs Frigate+:** Export pulls every snapshot in bulk instead of you picking
events. There are no false-positive submissions. A false positive is just an
image where you delete the wrong box.

### 2. Annotate

1. Click **Trainer** in the left sidebar. In the dropdown under **Dataset**
   at the top of the right-hand panel, pick `staging`.
2. **Pipeline Steps > Annotate**. Set **Teacher Model** to `yolo11l.pt` and
   **Confidence** to `0.7`, and leave **Merge with existing annotations**
   unticked.
3. Press **Annotate Dataset**.

> **Warning:** check the dropdown under **Dataset** at the top of the
> Trainer's right-hand panel says `staging`, and that everything
> you've reviewed has been moved out with the merge script. Annotate
> overwrites every label in the dataset, and with **Merge with existing
> annotations** ticked it brings back boxes you deleted. Never run it on
> `default`.

**vs Frigate+:** like suggested labels, except they're saved as real labels
straight away, for every image at once.

### 3. Review

1. Click **Viewer** in the left sidebar, then **Dataset**, which appears
   below **Settings**. In the dropdown at the far left of the Viewer's top
   toolbar, the one showing the open dataset's name, pick `staging`.
2. Click the **AI** tab at the top of the right-hand panel. In the dropdown
   under **Model**, pick `yolo11l.pt`. In the number box to its right (the
   confidence), enter `0.5`. Annotate only kept detections at 0.7 or above,
   so previewing at 0.5 also shows the borderline ones it skipped. Those are
   where its misses are. Nothing is saved, so the extra false hits cost
   nothing. The 0.5 resets on page reload.
3. On each image, press **Preview (no save)**. **Solid boxes** are the saved
   labels from Annotate. **Dashed boxes** are predictions and are never
   saved. A dashed box with no solid box is a likely miss.
4. **Wrong box (solid):** delete it, or right-click it to change its class.
   A wrong dashed box needs nothing, because it's never saved.
5. **Missed object (a dashed box with no solid box, or no box at all):** drag
   a box on the image, then right-click it to set its class. **New Box
   Class** in the **Edit** tab, at the top of the right-hand panel, sets the
   default class for new boxes.

- Edits save immediately. There's no "reviewed" marker, so note the number
  you stopped at.
- Two images showing the same moment from the same camera: if one is in
  `staging` and the other in `default`, delete the `staging` one. If both
  are in `staging`, delete either. For why, see "Lookalike snapshots" in
  section ["1. Collect"](#1-collect) of this README.

> **Warning:** never run the single-image Analyse while reviewing: the
> **◎ Analyse (A)** button in the **AI** tab, the **A** key, or **🤖 AI
> Analyse** in the image's right-click menu. It saves its own detections and
> brings back boxes you deleted. Use **Preview (no save)**. In the
> right-click menu, **AI Analyse** sits right next to **AI Preview**, so take
> care there. The **A** key is easy to hit by accident, so if boxes suddenly
> reappear, delete them again.

**vs Frigate+:** no verify step, no false-positive boxes and no "difficult"
flag. Fix a misidentification by changing or redrawing the box.

### 4. Merge into default (script)

```sh
scripts/datasets.sh merge
```

This moves everything into `default`, skips events `default` already has
(the reviewed copy wins), and empties `staging`.

Add `-n` (to this or `prune`) to list what it would move or delete without
changing anything.

> **Warning:** always run the merge script before the next Annotate, or that
> Annotate wipes the review. In other words, only ever run Annotate on a
> fresh batch of images. The one exception is adding a class (see section
> ["Updating the model"](#updating-the-model) of this README).

### 5. Train

1. Click **Trainer** in the left sidebar. In the dropdown under **Dataset**
   at the top of the right-hand panel, pick `default`.
2. **Pipeline Steps > Train**. Set **Base Model (Student)** to `yolo11s.pt`,
   and check Epochs, Batch Size, Image Size, Freeze Layers and
   **Augmentation** match section
   ["Settings > Training"](#settings--training) of this README.
3. Press **Start Training**.

- The output is `models/yolo11s-finetuned.pt`, overwritten on every run.
- The progress display can show 0% throughout. Real progress is in **Logs**
  and `data/datasets/output/finetune/results.csv`.
- For scale: about 33 s per epoch for about 500 images on a Ryzen 5 5600X
  (6 cores, 12 threads).
- Validation scores are optimistic, because val images come from the same
  cameras as train.

### 6. Export ONNX

1. Click **Trainer** in the left sidebar, then **Pipeline Steps > Export
   ONNX**. Set **Source Model** to `yolo11s-finetuned.pt`, **Image Size** to
   `320` and **Opset** to `13`. Tick **Simplify**, leave **Dynamic**
   unticked. Leave **FP16** unticked,
   even with a GPU. It makes the model expect FP16 input, which Frigate's
   `input_dtype` doesn't offer.
2. Press **Export ONNX**.

The result is `models/yolo11s-finetuned.onnx`.

### 7. Load it in Frigate

Copy the ONNX into Frigate's `config/model_cache/` under a versioned name, so
rolling back is a one-line change:

```yaml
model:
  path: /config/model_cache/alice-v1.onnx
  model_type: yolo-generic
  width: 320
  height: 320
  input_tensor: nchw
  input_dtype: float
  labelmap_path: /labelmap/coco-80.txt
```

Newer Frigate versions use a `models:` list with the same fields.

**vs Frigate+:** there's no `plus://` path to fill this in for you.

**Check Frigate's score filters.** Frigate ignores any single detection
scoring below `min_score` (default `0.5`). It only counts a tracked object
as real once the median of its recent scores reaches `threshold` (default
`0.7`). Both are set per label under `objects: filters:`, globally or per
camera. A new model scores the same object differently from the old one, so
the old values may now miss real objects or let false ones through.

After switching, compare a day of events with what you know happened:

- **Real objects missing**, or scoring just above `0.7` in Explore (open a
  tracked object, the details pane shows its scores): lower `threshold`, in
  steps of `0.05`. A missed object never reaches Explore, so you'll only
  notice it from footage.
- **False objects tracked:** raise `threshold`.
- Change `min_score` with it. The two interact, so keep `min_score` a little
  below `threshold`.

```yaml
objects:
  filters:
    person:
      min_score: 0.5
      threshold: 0.7
```

## Updating the model

Repeat steps 1-4 every few days. Train whenever `default` has grown enough to
be worth it.

Every export after your first, once `default` has images in it, also brings
back events you've already merged into `default`, as long as Frigate still
has them. Step 4 of section ["1. Collect"](#1-collect) of this README removes
them with `scripts/datasets.sh prune` before Dedup.

**vs Frigate+:** no model requests and no training limit, but it trains on
your hardware. Like Frigate+, each model is a fresh fine-tune on all your
reviewed images.

- **All trainings should be done from `yolo11s.pt`, not the finetuned model
  from the previous training** (`yolo11s-finetuned.pt`). Set it as **Base
  Model (Student)** in step 5 every time, and train on all of `default`.
  Starting from the previous model would carry its mistakes forward and keep
  classes you've dropped.
- Keep each deployed version (`alice-v1.onnx`, `alice-v2.onnx`, ...) in
  `model_cache` for rollback.
- **Re-reviewing labels already in `default`:** merged images aren't
  final. You can go back and fix any of them at any time, e.g. after
  spotting a mistake or tightening how you label something, and the fixes
  are used the next time you train. Do it **only by hand in the Viewer**:
  1. Click **Viewer** in the left sidebar, then **Dataset** below
     **Settings**. In the dropdown at the far left of the Viewer's top
     toolbar, pick `default`.
  2. Edit the same way as in section ["3. Review"](#3-review) of this
     README. **Preview (no save)** is safe to use here.

  > **Warning:** never run **Pipeline Steps > Annotate** to redo `default`.
  > It overwrites every label in it, wiping all your review. The only
  > exception is adding a class, in the next item of this list. Never run
  > the single-image Analyse on an image open in the Viewer either: the
  > **◎ Analyse (A)** button in the **AI** tab of the right-hand panel, the
  > **A** key, or **🤖 AI Analyse** in the image's right-click menu. It
  > saves its detections and brings back boxes you deleted. (**Preview (no
  > save)**, and **Live Detection** in the same tab, which only previews in
  > Dataset mode, are fine.) Don't panic if you do though: it only affects
  > the image you have open, not the whole dataset. It adds its detections
  > next to your existing boxes, so delete the extra ones it brought back.
- **Adding a class to an existing dataset:** this is the one safe use of
  Annotate on `default`, because your existing labels contain none of the
  new class.
  1. Click **Settings** in the left sidebar, then **AI** in the top
     toolbar. Under **Classes**, untick every class you currently
     use and tick only the new one. Note which ones you unticked, because
     you'll tick them again in step 5. **Save**.
  2. Click **Trainer** in the left sidebar. In the dropdown under
     **Dataset** at the top of the right-hand panel, pick `default`. Then
     open **Pipeline Steps > Annotate** and tick **Merge with existing
     annotations**.
  3. Before pressing anything, check that only the new class is ticked
     (step 1) and that **Merge with existing annotations** is ticked. Any
     other class left ticked gets its deleted boxes brought back, and with
     "Merge" unticked "Annotate" wipes every label in `default`. Then press
     **Annotate Dataset**.
  4. Review the new boxes: click **Viewer** in the left sidebar, then
     **Dataset** below **Settings**. In the dropdown at the far left of the
     Viewer's top toolbar, pick `default`. Then, in the same toolbar, open
     the dropdown reading **All classes** (right after the **Empty** button)
     and pick the new class, so only images containing it are shown. Fix
     them the same way as in section ["3. Review"](#3-review) of this README.
  5. Click **Settings** in the left sidebar, then **AI** in the top
     toolbar. Tick the classes you unticked in step 1 again
     (keeping the new one ticked), **Save**.
- **Removing a class from an existing dataset:**
  1. Click **Settings** in the left sidebar, then **AI** in the top
     toolbar. Untick the class under **Classes**, then **Save**.
     Annotate and Analyse stop adding it.
  2. alice can't bulk-delete boxes, so remove the existing ones on disk. Find
     the class's ID in `data/datasets/default/dataset.yaml`, then (cat is
     `15`):

     ```sh
     sed -i '/^15 /d' data/datasets/default/labels/*/*.txt
     ```

     Run it on `staging` too if it has reviewed labels.
  3. Retrain.

  The model then learns that class as background and stops detecting it. If
  you only want Frigate to ignore it, leave the labels alone and remove it
  from Frigate's `objects: track` instead.

## Quirks

| Feature                                                                        | Behaviour                                                                                                                                                                  | Workaround                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Trainer > Run Selected Pipeline                                                | Steps whose page isn't open use alice's built-in defaults instead of your settings: pHash 85, augmentation off, ONNX 640, Max Images 100.                                  | Run each step from its own page.                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Trainer > Export page fields                                                   | Only **Max Images** does anything. The other fields and the **External Folder** source are ignored.                                                                        | Use the dropdown under **Dataset** at the top of the Trainer's right-hand panel, and **Settings > Paths**.                                                                                                                                                                                                                                                                                                                                                                                                     |
| Trainer > Export > Max Images                                                  | Resets to 100.                                                                                                                                                             | Set it right before pressing **Export Dataset**.                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Settings > **✓ Save**, with alice open in more than one browser tab | **✓ Save** writes every setting on every Settings section (Paths, AI, Training, ...), not just the ones you changed. A browser tab that was opened before you changed a setting in another browser tab still shows the old values, and saving there puts them all back. | Keep alice open in one browser tab. If you have it open in more than one, reload the browser tab you are in before changing anything in Settings. |
| Viewer > Live mode > **Info** tab (right-hand panel) > **Transfer to Dataset** | The snapshot arrives unlabelled. **Never press "Move"**: it tries to delete the snapshot from Frigate. The read-only mount stops it, but it would succeed with write access. | Use **Copy (M)**. Then label just that image in the Viewer, not in the Trainer: click **Dataset** in the left sidebar (it's visible, since Live mode is in the Viewer), pick the target dataset in the dropdown at the far left of the top toolbar, and open the copied image. In the **AI** tab at the top of the right-hand panel, enter 0.7 in the number box right of the **Model** dropdown, then press **Analyse (A)**. Never use **Pipeline Steps > Annotate** for this. It relabels the whole dataset. |
| Viewer > Dataset > Edit > Copy/Move                                            | One image at a time.                                                                                                                                                       | Use `scripts/datasets.sh merge` for batches.                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| Viewer > AI tab > number box right of the **Model** dropdown (confidence)      | Shared by all Viewer modes, and **Analyse (A)** uses it.                                                                                                                   | Press **Reset** before Analyse.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Viewer > AI tab > Live Detection                                               | Can't keep up in Video mode on CPU.                                                                                                                                        | Pause on a frame and use **Preview (no save)**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Trainer status popups                                                          | Can report 0 when the step did work.                                                                                                                                       | Check **Logs**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
