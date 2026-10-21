with Shapes;
package Other is
   type Blob is new Shapes.Shape with null record;  --  tagged_type_hierarchy: not a parent unit
end Other;
