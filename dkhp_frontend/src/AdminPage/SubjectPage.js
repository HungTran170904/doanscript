import { useContext, useEffect, useState } from "react";
import SubjectForm from "../AdminComponent/SubjectForm";
import { addSubject, getAllSubjects, removeSubject } from "../API/SubjectAPI";
import { AdminContext } from "../Router/AdminRouter";
import { FormModal } from "../AdminComponent/ModalAndAlert";
import TableHeader from "../Component/TableHeader";
import { useSnackbar } from "notistack";

const SubjectPage=()=>{
          const {setError}=useContext(AdminContext);
          const [subjectData, setSubjectData]=useState([]);
          const[show, setShow]=useState(0); //0: ko show, 1:show
          const [searchTerm, setSearchTerm]=useState("");
          const [search, setSearch]=useState("");
          const { enqueueSnackbar } = useSnackbar();
          const config = {variant: '',anchorOrigin:{ horizontal: 'center' , vertical: 'bottom'}}
          const newSubject={
                    subjectId:"",
                    subjectName:"",
                    theoryCreditNumber:0,
                    practiceCreditNumber:0,
                    prerequisiteSubjectIds:"",
                    aheadSubjectIds:""
          }
          useEffect(()=>{
                    getAllSubjects().then(res=>{
                              setSubjectData(res.data);
                    })
          },[])
            const handleAddButton=(e)=>{
                    e.preventDefault();
                    setShow(1);
          }
          const handleDelButton=(e,id)=>{
                    e.preventDefault();
                    removeSubject(id).then(res=>{
                            setSubjectData((preSubjectData)=>{
                                return preSubjectData.filter((data)=>data.id!=id)
                            })
                            config.variant="success";
                            enqueueSnackbar("Xóa thành công môn "+res.data, config);
                    })
                    .catch(err=>setError(err))
          }
          function addRelations(subjectDTO,subjectIds, type){
                subjectIds.replace(" ","").split(",").forEach((value)=>{
                    if(value&&value.length!=0) 
                        subjectDTO.relations.push({
                            subjectId: value,
                            type: type
                    })
                })
          }
          const handleSubmit=()=>{
                const subjectDTO={
                    subjectId: newSubject.subjectId,
                    subjectName: newSubject.subjectName,
                    theoryCreditNumber: newSubject.theoryCreditNumber,
                    practiceCreditNumber: newSubject.practiceCreditNumber
                }
                subjectDTO.relations=[];
                addRelations(subjectDTO, newSubject.prerequisiteSubjectIds,1);
                addRelations(subjectDTO, newSubject.aheadSubjectIds,2);
                addSubject(subjectDTO).then(res=>{
                    setSubjectData((prevSubjectData)=>{
                        const updatedSubjectData=[...prevSubjectData];
                        updatedSubjectData.push(res.data);
                        return updatedSubjectData;
                    })
                    config.variant="success";
                    enqueueSnackbar("Thêm thành công môn "+res.data.subjectId, config);
                    setShow(0);
                })
                .catch(err=>{
                    if(err.response.status==400){
                        config.variant="error";
                        enqueueSnackbar(err.response.data, config);
                    }
                    else setError(err)
                })
        }
        const handleFilter = (item) => {
            const re = new RegExp("^"+search,"i");
            return item.subjectId.match(re);
        }
        const filterSubjects=(search==="")?subjectData:subjectData.filter(handleFilter);
          return(
                    <>
                    <div className="main-page">
                              <div className="ContentAlignment">
                                        <h1>Danh sách các môn học</h1>
                                        <button  type="button" className="btn btn-success" onClick={(e)=>handleAddButton(e)}>Add Subject</button>
                                        <form className="d-flex col-lg-6" role="search" onSubmit={(e)=>{e.preventDefault(); setSearch(searchTerm);}}>
                                                  <input className="form-control me-2" type="search" placeholder="Tìm kiếm theo mã lớp" id="Search" onChange={(e)=>setSearchTerm(e.target.value)}/>
                                                  <button className="btn btn-outline-success" type="submit" >Search</button>
                                        </form>
                              </div>
                              <div className="TableWapper border-bottom border-dark">
                                  <table className="table table-hover">
                                      <TableHeader data={["Mã Môn","Tên Môn","Số TCTH","Số TCLT","Mã MH tiên quyết","Mã MH học trước","Action"]} />
                                      <tbody>
                                  {filterSubjects?.map((data)=> {
                                          return (
                                              <tr key={data.id}>
                                                  <th>{data.subjectId}</th>
                                                  <td>{data.subjectName}</td>
                                                  <td>{data.theoryCreditNumber}</td>
                                                  <td>{data.practiceCreditNumber}</td>
                                                  <td>{data.relations&&data.relations.map((rs)=>{
                                                           if(rs.type==1) return(<div>{rs.subjectId}</div>)
                                                  })}</td>
                                                  <td>{data.relations&&data.relations.map((rs)=>{
                                                           if(rs.type==2) return(<div>{rs.subjectId}</div>)
                                                  })}</td>
                                                  <td colSpan={2}>
                                                            <button type="button" className="btn btn-danger mr-2" onClick={(e)=>handleDelButton(e,data.id)}>Delete</button>
                                                            <button type="button" className="btn btn-primary">Modify</button>
                                                  </td>
                                              </tr>
                                          )
                                      })}
                                      </tbody>
                                  </table>
                              </div>
                    </div>
                      {show==1&&<FormModal setShow={setShow} handleSubmit={handleSubmit} title="THÊM MÔN HỌC"><SubjectForm newSubject={newSubject}/></FormModal>}
                    </>
          )
}
export default SubjectPage;