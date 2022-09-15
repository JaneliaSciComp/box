#!/usr/local/python-2.7.8/bin/python
import MySQLdb as sql
import argparse

def dbConnect():
    db = sql.connect(host='mysql3',user='sageRead',passwd='sageRead',db='sage')
    c = db.cursor() 
    return(c,db);

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Fetch line properties')
    parser.add_argument('line',help='line name')
    parser.add_argument('property',help='line property')
    args = parser.parse_args()
    line = args.line
    property = args.property
    (cursor,db) = dbConnect()
    if (property == '*'):
        stmt= "SELECT type,value FROM line_property_vw WHERE name='%s' ORDER BY 1" % (line)
    else:
        stmt = "SELECT value FROM line_property_vw WHERE name='%s' AND type='%s'" % (line,property);
    cursor.execute(stmt)
    rows = cursor.fetchall()
    if len(rows):
        if (property != '*'):
            print rows[0][0]
        else:
            for row in rows:
                print "%s\t%s" % (row[0],row[1])
