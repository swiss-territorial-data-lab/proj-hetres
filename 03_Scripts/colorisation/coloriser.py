import pdal
import os
import time
import json


in_laz_dir = "./tutoriel_metropole/lidar/"
in_tif_dir = "./tutoriel_metropole/ortho/"
out_laz_dir = "./tutoriel_metropole/lidar_colorise/"
os.makedirs(out_laz_dir, exist_ok=True)

tiles = [i.split(".")[0] for i in os.listdir(in_laz_dir)]

start = time.time()
for i, t in enumerate(tiles):
    in_laz = in_laz_dir + f"{t}.laz"
    in_tif = in_tif_dir + f"{t}.tif"
    out_laz = out_laz_dir + f"{t}.laz"

    print(f"Dalle {i + 1} ({t}) sur {len(tiles)}...")
    if not os.path.isfile(in_tif):
        print(f"\tErreur : le fichier {in_tif} n'existe pas")
        continue

    pipeline_json = json.dumps(
        [
            {
                "type":"readers.las",
                "filename":f"{in_laz}",
                "spatialreference":"EPSG:3946",
                "compression":"lazperf"
            },
            {
                "type":"filters.colorization",
                "raster":f"{in_tif}"
            },
            {
                "type":"writers.las",
                "filename":f"{out_laz}",
                "a_srs":"EPSG:3946",
                "compression":"lazperf"
            }
        ]
    )

    pipeline = pdal.Pipeline(pipeline_json)
    start_iter = time.time()
    pipeline.execute()
    end_iter = time.time()

    print(f"Dalle {i + 1} traitée ({end_iter - start_iter} secondes, {end_iter - start} total)...")
