========================
Reading and Writing Data
========================

Recipes related to reading and writing data from disk using
Apache Arrow.

.. contents::

Write a Parquet file
====================

.. testsetup::

    import numpy as np
    import pyarrow as pa

    arr = pa.array(np.arange(100))

Given an array with all numbers from 0 to 100

.. testcode::

    print(f"{arr[0]} .. {arr[-1]}")

.. testoutput::

    0 .. 99

To write it to a Parquet file, as Parquet is a columnar format,
we must create a :class:`pyarrow.Table` out of it,
so that we get a table of a single column which can then be
written to a Parquet file. 

.. testcode::

    table = pa.Table.from_arrays([arr], names=["col1"])

Once we have a table, it can be written to a Parquet File 
using the functions provided by the ``pyarrow.parquet`` module

.. testcode::

    import pyarrow.parquet as pq

    pq.write_table(table, "example.parquet", compression=None)

Reading a Parquet file
======================

Given a Parquet file, it can be read back to a :class:`pyarrow.Table`
by using :func:`pyarrow.parquet.read_table` function

.. testcode::

    import pyarrow.parquet as pq

    table = pq.read_table("example.parquet")

The resulting table will contain the same columns that existed in
the parquet file as :class:`ChunkedArray`

.. testcode::

    print(table)

    col1 = table["col1"]
    print(f"{type(col1).__name__} = {col1[0]} .. {col1[-1]}")

.. testoutput::

    pyarrow.Table
    col1: int64
    ChunkedArray = 0 .. 99

Reading a subset of Parquet data
================================

When reading a Parquet file with :func:`pyarrow.parquet.read_table` 
it is possible to restrict which Columns and Rows have to be read
in memory by using the ``filters`` and ``columns`` arguments

.. testcode::

    import pyarrow.parquet as pq

    table = pq.read_table("example.parquet", 
                          columns=["col1"],
                          filters=[
                              ("col1", ">", 5),
                              ("col1", "<", 10),
                          ])

The resulting table will contain only the projected columns
and filtered rows. Refer to :func:`pyarrow.parquet.read_table`
documentation for details about filters syntax.

.. testcode::

    print(table)

    col1 = table["col1"]
    print(f"{type(col1).__name__} = {col1[0]} .. {col1[-1]}")

.. testoutput::

    pyarrow.Table
    col1: int64
    ChunkedArray = 6 .. 9
    

Saving Arrow Arrays to disk
===========================

Apart using arrow to read and save common file formats like Parquet,
it is possible to dump data in the raw arrow format which allows 
direct memory mapping of data from disk. 

Given an array with all numbers from 0 to 100

.. testcode::

    print(f"{arr[0]} .. {arr[-1]}")

.. testoutput::

    0 .. 99

We can save the array by making a :class:`pyarrow.RecordBatch` out
of it and writing the record batch to disk.

.. testcode::

    schema = pa.schema([
        pa.field('nums', arr.type)
    ])

    with pa.OSFile('arraydata.arrow', 'wb') as sink:
        with pa.ipc.new_file(sink, schema=schema) as writer:
            batch = pa.record_batch([arr], schema=schema)
            writer.write(batch)

If we were to save multiple arrays into the same file,
we would just have to adapt the ``schema`` accordingly and add
them all to the ``record_batch`` call.

Memory Mapping Arrow Arrays from disk
=====================================

Arrow arrays that have been written to disk in the Arrow
format itself can be memory mapped back directly from the disk.

.. testcode::

    with pa.memory_map('arraydata.arrow', 'r') as source:
        loaded_arrays = pa.ipc.open_file(source).read_all()

.. testcode::

    arr = loaded_arrays[0]
    print(f"{arr[0]} .. {arr[-1]}")

.. testoutput::

    0 .. 99

Writing CSV files
=================

It is currently possible to write an Arrow :class:`pyarrow.Table` to
CSV by going through pandas. Arrow doesn't currently provide an optimized
code path for writing to CSV.

.. testcode::

    table = pa.Table.from_arrays([arr], names=["col1"])
    table.to_pandas().to_csv("table.csv", index=False)

Reading CSV files
=================

Arrow can read :class:`pyarrow.Table` entities from CSV using an
optimized codepath that can leverage multiple threads.

.. testcode::

    import pyarrow.csv

    table = pa.csv.read_csv("table.csv")

Arrow will do its best to guess data types, further options can be
provided to :func:`pyarrow.csv.read_csv` to drive
:class:`pyarrow.csv.ConvertOptions`.

.. testcode::

    print(table)

    col1 = table["col1"]
    print(f"{type(col1).__name__} = {col1[0]} .. {col1[-1]}")

.. testoutput::

    pyarrow.Table
    col1: int64
    ChunkedArray = 0 .. 99

Reading Partitioned data
========================

In some cases, your dataset might be composed by multiple separate
files each containing a piece of the data. 

.. testsetup::

    import pathlib
    import pyarrow.parquet as pq

    examples = pathlib.Path("examples")
    examples.mkdir(exist_ok=True)

    pq.write_table(pa.table({"col1": range(10)}), 
                   examples / "dataset1.parquet", compression=None)
    pq.write_table(pa.table({"col1": range(10, 20)}), 
                   examples / "dataset2.parquet", compression=None)
    pq.write_table(pa.table({"col1": range(20, 30)}), 
                   examples / "dataset3.parquet", compression=None)

In this case the :func:`pyarrow.dataset.dataset` function provides
an interface to discover and read all those files as a single big dataset.

For example if we have a structure like:

.. code-block::

    examples/
    ├── dataset1.parquet
    ├── dataset2.parquet
    └── dataset3.parquet

Then, pointing the ``dataset`` function to the ``examples`` directory
will discover those parquet files and will expose them all as a single
dataset:

.. testcode::

    import pyarrow.dataset as ds

    dataset = ds.dataset("./examples", format="parquet")
    print(dataset.files)

.. testoutput::

    ['./examples/dataset1.parquet', './examples/dataset2.parquet', './examples/dataset3.parquet']

The whole dataset can be viewed as a single big table using
:meth:`pyarrow.dataset.Dataset.to_table`. While each parquet file
contains only 10 rows, converting the dataset to a table will
expose them as a single block of data

.. testcode::

    table = dataset.to_table()
    print(table)

    col1 = table["col1"]
    print(f"{type(col1).__name__} = {col1[0]} .. {col1[-1]}")

.. testoutput::

    pyarrow.Table
    col1: int64
    ChunkedArray = 0 .. 29

Notice that converting to a table will force all data to be loaded 
in memory, which for big datasets is not what you usually want.

For this reason, it might be better to rely on the 
:meth:`pyarrow.dataset.Dataset.to_batches` method, which allows to
iteratively load a chunk of data at the time returning a 
:class:`pyarrow.RecordBatch` for each one of them.

.. testcode::

    for record_batch in dataset.to_batches():
        col1 = record_batch.column("col1")
        print(f"{col1._name} = {col1[0]} .. {col1[-1]}")

.. testoutput::

    col1 = 0 .. 9
    col1 = 10 .. 19
    col1 = 20 .. 29

Reading Partitioned Data from S3
================================

The :class:`pyarrow.dataset.Dataset` is also able to abstract
partitioned data coming from remote sources like S3 or HDFS.

.. testcode::

    from pyarrow import fs

    # List content of s3://ursa-labs-taxi-data/2011
    s3 = fs.SubTreeFileSystem("ursa-labs-taxi-data", fs.S3FileSystem(region="us-east-2"))
    for entry in s3.get_file_info(fs.FileSelector("2011", recursive=True)):
        if entry.type == fs.FileType.File:
            print(entry.path)

.. testoutput::

    2011/01/data.parquet
    2011/02/data.parquet
    2011/03/data.parquet
    2011/04/data.parquet
    2011/05/data.parquet
    2011/06/data.parquet
    2011/07/data.parquet
    2011/08/data.parquet
    2011/09/data.parquet
    2011/10/data.parquet
    2011/11/data.parquet
    2011/12/data.parquet

The data in the bucket can be loaded as a single big dataset partitioned
by ``month`` using

.. testcode::

    dataset = ds.dataset("s3://ursa-labs-taxi-data/2011", 
                         partitioning=["month"])
    for f in dataset.files[:10]:
        print(f)
    print("...")

.. testoutput::

    ursa-labs-taxi-data/2011/01/data.parquet
    ursa-labs-taxi-data/2011/02/data.parquet
    ursa-labs-taxi-data/2011/03/data.parquet
    ursa-labs-taxi-data/2011/04/data.parquet
    ursa-labs-taxi-data/2011/05/data.parquet
    ursa-labs-taxi-data/2011/06/data.parquet
    ursa-labs-taxi-data/2011/07/data.parquet
    ursa-labs-taxi-data/2011/08/data.parquet
    ursa-labs-taxi-data/2011/09/data.parquet
    ursa-labs-taxi-data/2011/10/data.parquet
    ...

The dataset can then be used with :meth:`pyarrow.dataset.Dataset.to_table`
or :meth:`pyarrow.dataset.Dataset.to_batches` like you would for a local one.

.. note::

    It is possible to load partitioned data also in the ipc arrow
    format or in feather format.

Write a Feather file
====================

.. testsetup::

    import numpy as np
    import pyarrow as pa

    arr = pa.array(np.arange(100))

Given an array with all numbers from 0 to 100

.. testcode::

    print(f"{arr[0]} .. {arr[-1]}")

.. testoutput::

    0 .. 99

To write it to a Feather file, as Feather is a columnar format,
we must create a :class:`pyarrow.Table` out of it,
so that we get a table of a single column which can then be
written to a Feather file. 

.. testcode::

    table = pa.Table.from_arrays([arr], names=["col1"])

Once we have a table, it can be written to a Feather File 
using the functions provided by the ``pyarrow.feather`` module

.. testcode::

    import pyarrow.feather as ft
    
    ft.write_feather(table, 'example.feather')

Reading a Feather file
======================

Given a Feather file, it can be read back to a :class:`pyarrow.Table`
by using :func:`pyarrow.feather.read_table` function

.. testcode::

    import pyarrow.feather as ft

    table = ft.read_table("example.feather")

The resulting table will contain the same columns that existed in
the parquet file as :class:`ChunkedArray`

.. testcode::

    print(table)

    col1 = table["col1"]
    print(f"{type(col1).__name__} = {col1[0]} .. {col1[-1]}")

.. testoutput::

    pyarrow.Table
    col1: int64
    ChunkedArray = 0 .. 99
