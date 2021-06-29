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