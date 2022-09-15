#!/usr/local/python-2.7.8/bin/python
import MySQLdb as sql
import argparse

def dbConnect():
    db = sql.connect(host='mysql3',user='sageRead',passwd='sageRead',db='sage')
    c = db.cursor() 
    return(c,db);

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Fetch line name')
    parser.add_argument('image',help='image name')
    args = parser.parse_args()
    image = args.image
    (cursor,db) = dbConnect()
    stmt = "SELECT line FROM image_vw WHERE name='%s'" % (image);
    cursor.execute(stmt)
    rows = cursor.fetchall()
    if (len(rows) == 1):
        print rows[0][0]
