#!/usr/local/python-2.7.8/bin/python
import MySQLdb as sql
import argparse

def dbConnect():
    db = sql.connect(host='mysql3',user='sageRead',passwd='sageRead',db='sage')
    c = db.cursor() 
    return(c,db);

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Fetch image property')
    parser.add_argument('image',help='image name')
    parser.add_argument('property',help='image property')
    args = parser.parse_args()
    image = args.image
    property = args.property
    (cursor,db) = dbConnect()
    if (property == '*'):
        stmt= "SELECT type,value FROM image_property_vw ipv JOIN image i ON (i.id=ipv.image_id) WHERE i.name='%s' ORDER BY 1" % (image)
    else:
        stmt = "SELECT value FROM image_property_vw ipv JOIN image i ON (i.id=ipv.image_id) WHERE i.name='%s' AND ipv.type='%s'" % (image,property);
    cursor.execute(stmt)
    rows = cursor.fetchall()
    if len(rows):
        if (property != '*'):
            print rows[0][0]
        else:
            for row in rows:
                print "%s\t%s" % (row[0],row[1])
