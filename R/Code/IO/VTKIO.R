# Functions for reading/writing VTK format data
# currently limited to VTK point formats
# for use with Daniel Rueckert's IRTK toolkit

#' Write 3D landmarks in VTK legacy format 
#' 
#' default title is:
#' Data written from R by WriteVTKLandmarks at <time>
#'  
#' See http://www.vtk.org/VTK/img/file-formats.pdf for details
#' @param filename path to output file 
#' @param d a matrix or dataframe with 3 columns
#' @param title A description of the file contents (See details)
#' @param datatype float (default) or double
#' @author jefferis
#' @export
WriteVTKLandmarks<-function(filename,d,title,datatype=c("float","double")){
	if(ncol(d)!=3) stop("Expect N rows x 3 cols of 3d points")
	nummarkers=nrow(d)
	datatype=match.arg(datatype)
	if(missing(title)) title=paste("Data written from R by WriteVTKLandmarks at",Sys.time())
	
	cat("# vtk DataFile Version 2.0",
		title,
		"ASCII",
		"DATASET POLYDATA",
		paste("POINTS",nummarkers,datatype),sep="\n",file=filename)

	write.table(d,col.names=F,row.names=F,file=filename,append=TRUE)
}

#' Reads landmarks from a file in VTK's legacy data format
#' 
#' The matrix will have attributes including
#' * file - original filename
#' * title - description of data from VTK file
#' * vtk_datatype - VTK data type
#' @param filename path to VTK input file
#' @return matrix with 3 columns and npoints rows 
#' @author jefferis
#' @export
ReadVTKLandmarks<-function(filename){
	if(!file.exists(filename)) stop("Cannot read: ",filename)
	con=file(filename,open='rb',encoding='ASCII')
	on.exit(close(con))
	magic=readLines(con,n=1)
	if(regexpr("# vtk DataFile Version [23]",magic,ignore=T)<0)
		stop("Bad header line in file: ",filename)
	
	title=readLines(con,1)
	encoding=readLines(con,1)
	if(regexpr("ASCII",encoding,ignore.case=TRUE)<0)
		stop("Can only read ASCII encoded VTK pointsets")

	datasetLine=toupper(readLines(con,1))
	if(regexpr("^DATASET",datasetLine)<0)
		stop("Missing DATASET line")

	datasetType=sub("DATASET\\s+(\\w+)","\\1",datasetLine)
	
	validDatasetTypes<-c("STRUCTURED_POINTS", "STRUCTURED_GRID",
	"UNSTRUCTURED_GRID", "POLYDATA", "RECTILINEAR_GRID", "FIELD")

	if(!datasetType%in%validDatasetTypes)
		stop(datasetType," is not a valid VTK dataset type")
	if(datasetType!="POLYDATA")
		stop("ReadVTKLandmarks can currently only read POLYDATA.",
			" See http://www.vtk.org/VTK/img/file-formats.pdf for details.")
	
	pointsLine=toupper(readLines(con,1))
	if(regexpr("POINTS",pointsLine)<0)
		stop("Missing POINTS definition line")
	ptinfo=unlist(strsplit(pointsLine,"\\s+",perl=TRUE))
	if(length(ptinfo)!=3)
		stop("Unable to extract points information from POINTS line",pointsLine)
	nummarkers=as.integer(ptinfo[2])
	if(is.na(nummarkers))
		stop("Unable to extract number of points from POINTS line:",pointsLine)
	datatype=ptinfo[3]
	if(!datatype%in%toupper(c("unsigned_char", "char", "unsigned_short", "short", "unsigned_int", "int",
		"unsigned_long", "long", "float", "double")))
		stop("Unrecognised VTK datatype: ",datatype)
	
	# VTK seems to be hardcoded for 3D
	points=scan(con,what=1.0,n=3*nummarkers,quiet=TRUE) 
	m=matrix(points,ncol=3,byrow=T)
	colnames(m)=c("X","Y","Z")
	attr(m,"file")=filename
	attr(m,"title")=title
	attr(m,"vtk_datatype")=datatype
	m
}

#' Write 3D mesh in VTK legacy format 
WriteVTKMesh<-function(filename,d,title,datatype=c("float","double")){
  if(!inherits(d, "mesh3d")) d=nat::as.mesh3d(d)
  xyz=t(d$vb[1:3, ])
  numpoints=nrow(xyz)
  datatype=match.arg(datatype)
  if(missing(title)) title=paste("Data written from R by WriteVTKMesh at",Sys.time())
  
  cat("# vtk DataFile Version 2.0",
      title,
      "ASCII",
      "DATASET POLYDATA",
      paste("POINTS",numpoints,datatype),sep="\n",file=filename)
  
  write.table(xyz,col.names=F,row.names=F,file=filename,append=TRUE)
  
  # now for the polygon info
  faces=if(!is.null(d$ib)) t(d$ib) else t(d$it)
  nfaces=nrow(faces)
  points_per_face=ncol(faces)
  nints=nfaces*(points_per_face+1)
  cat(sprintf("POLYGONS %d %d\n", nfaces, nints), file = filename, append = T)
  write.table(cbind(points_per_face, faces), col.names=F, row.names=F, 
              file=filename, append=TRUE)
  cat("", paste("CELL_DATA", nfaces), paste("POINT_DATA", numpoints), sep="\n",
      file = filename, append = T)
}
